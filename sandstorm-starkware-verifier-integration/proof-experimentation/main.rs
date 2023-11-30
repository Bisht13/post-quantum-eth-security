#![feature(slice_as_chunks)]

use std::collections::BTreeSet;
use std::iter::zip;
use std::{fmt::Display, fs::File};
use sandstorm_layouts::CairoAirConfig;
use ark_poly::{Radix2EvaluationDomain, EvaluationDomain};
use ark_serialize::CanonicalDeserialize;
use ministark::Proof;
use ministark::channel::VerifierChannelArtifacts;
use ministark::fri::{get_query_values, LayerProof, fold_positions};
use ministark::utils::SerdeOutput;
use ministark_gpu::fields::p3618502788666131213697322783095070105623107215331596699973092056135872020481::ark::Fp;
use ark_ff::Field;
use ministark::stark::Stark;
use ministark_gpu::utils::bit_reverse_index;
use num_bigint::BigUint;
use ruint::{aliases::U256, uint};
use sandstorm::claims::starknet::EthVerifierClaim;
use sandstorm::input::CairoAuxInput;
use sandstorm_binary::{AirPublicInput, CompiledProgram, MemoryEntry};
use sandstorm_crypto::hash::keccak::{MaskedKeccak256HashFn, CanonicalKeccak256HashFn};
use sandstorm_crypto::merkle::{LeafVariantMerkleTree, LeafVariantMerkleTreeProof};
use sandstorm_crypto::utils::to_montgomery;
use sha2::Digest;
use sha3::Keccak256;
use std::io::Write;

const AIR_PUBLIC_INPUT_BYTES: &[u8] = include_bytes!("../air-public-input.json");
const PROOF_BYTES: &[u8] = include_bytes!("../bootloader-proof.bin");
const PROGRAM_BYTES: &[u8] = include_bytes!("../bootloader_compiled.json");

type SharpClaim = EthVerifierClaim;
type SharpProof = Proof<EthVerifierClaim>;

fn fri_io_hash<const N: usize>(
    domain_size: usize,
    indices: &[usize],
    layer: &LayerProof<
        Fp,
        SerdeOutput<Keccak256>,
        LeafVariantMerkleTree<MaskedKeccak256HashFn<20>>,
    >,
) -> SerdeOutput<Keccak256> {
    let domain = Radix2EvaluationDomain::<Fp>::new(domain_size).unwrap();
    let (chunks, _) = layer.flattenend_rows.as_chunks::<N>();
    let evals = get_query_values(chunks, indices, &fold_positions(indices, N));
    let mut hasher = Keccak256::new();
    for (index, eval) in zip(indices, evals) {
        hasher.update(U256::from(index + domain_size).to_be_bytes::<32>());
        hasher.update(to_montgomery(eval).to_be_bytes::<32>());
        hasher.update(
            U256::from(BigUint::from(
                domain
                    .element(bit_reverse_index(domain_size, *index))
                    .inverse()
                    .unwrap(),
            ))
            .to_be_bytes::<32>(),
        );
    }
    SerdeOutput::new(hasher.finalize())
}

fn main() -> std::io::Result<()> {
    let air_public_input: AirPublicInput<Fp> =
        serde_json::from_reader(AIR_PUBLIC_INPUT_BYTES).unwrap();
    println!("public input: {:?}", air_public_input);
    let program: CompiledProgram<Fp> = serde_json::from_reader(PROGRAM_BYTES).unwrap();
    let claim = SharpClaim::new(program, air_public_input);
    let proof: SharpProof = Proof::deserialize_compressed(PROOF_BYTES).unwrap();
    let verification_artifacts = claim.verify(proof.clone(), 80).unwrap();

    let mut output = File::create("./test/AutoGenProofData.sol")?;
    write!(
        output,
        "{}",
        gen_proof_data_class(claim, verification_artifacts, proof)
    )
}

struct FriLayerStatement {
    fri_queue: Vec<U256>,
    proof: Vec<U256>,
    eval_point: U256,
    step_size: U256,
    root: U256,
    input_hash: U256,
}

fn gen_fri_layer_statement<const N: usize>(
    positions: &[usize],
    evaluations: &[Fp],
    layer: &LayerProof<
        Fp,
        SerdeOutput<Keccak256>,
        LeafVariantMerkleTree<MaskedKeccak256HashFn<20>>,
    >,
    domain_size: usize,
    alpha: Fp,
) -> FriLayerStatement {
    let mut fri_queue = Vec::new();
    let lde_domain = Radix2EvaluationDomain::<Fp>::new(domain_size).unwrap();

    for (pos, deep_eval) in zip(positions, evaluations) {
        // each fri_queue input (query_index, FRI_value, FRI_inverse_point)
        fri_queue.push(U256::from(*pos + domain_size));
        fri_queue.push(to_montgomery(*deep_eval));
        fri_queue.push(U256::from(BigUint::from(
            lde_domain
                .element(bit_reverse_index(domain_size, *pos))
                .inverse()
                .unwrap(),
        )));
    }

    // add delimiter cell
    fri_queue.push(U256::ZERO);

    let mut fri_proof = Vec::new();

    let cosets = layer.flattenend_rows.chunks(N);
    println!("pos len: {}", positions.len());
    println!("folded pos len: {}", fold_positions(positions, N).len());
    println!("cosets len: {}", cosets.len());

    let pos_set = BTreeSet::from_iter(positions);
    for (pos, coset) in zip(fold_positions(positions, N), cosets) {
        for (i, v) in coset.iter().enumerate() {
            if !pos_set.contains(&(pos * N + i)) {
                fri_proof.push(to_montgomery(*v))
            }
        }
    }

    let indices = fold_positions(positions, N);
    let fri_merkle_vals =
        get_merkle_statement_values(&layer.commitment, layer.merkle_proof.clone(), &indices);
    fri_proof.extend(fri_merkle_vals.view);

    let root = U256::try_from_be_slice(&layer.commitment[0..32]).unwrap();
    println!("fri root is: {}", root);

    let input_hash =
        U256::try_from_be_slice(&fri_io_hash::<N>(domain_size, positions, layer)[0..32]).unwrap();

    FriLayerStatement {
        fri_queue,
        eval_point: U256::from(BigUint::from(alpha)),
        root,
        step_size: U256::from(N.ilog2()),
        proof: fri_proof,
        input_hash,
    }
}

fn gen_proof_data_class(
    claim: SharpClaim,
    metadata: VerifierChannelArtifacts<Fp>,
    proof: SharpProof,
) -> String {
    let mut res = String::new();

    type A = <SharpClaim as Stark>::AirConfig;
    let (public_memory_z, public_memory_alpha) =
        A::public_memory_challenges(&metadata.air_challenges);
    let public_memory_quotient = A::public_memory_quotient(&metadata.air_hints);
    let mut public_memory_product = Fp::ONE;
    for &MemoryEntry { address, value } in &claim.public_input().public_memory {
        let address = Fp::from(address);
        public_memory_product *= public_memory_z - (address + value * public_memory_alpha);
    }

    println!("YOO public memory product: {}", public_memory_quotient);

    let public_inputs = claim.get_public_inputs();
    let sharp_public_input = CairoAuxInput(&public_inputs);
    println!("sharp public input: {:?}", sharp_public_input.public_input_elements::<CanonicalKeccak256HashFn>());

    let public_memory_product: BigUint = public_memory_product.into();
    let public_memory_z: BigUint = public_memory_z.into();
    let public_memory_alpha: BigUint = public_memory_alpha.into();

    let cairo_aux_elements = [
        sharp_public_input.public_input_elements::<CanonicalKeccak256HashFn>(),
        vec![
            U256::from(public_memory_product),
            U256::from(public_memory_z),
            U256::from(public_memory_alpha),
        ],
    ]
    .concat();
    let fmt_cairo_aux_inputs = fmt_array_items(&cairo_aux_elements);

    let proof_params = fmt_array_items(&get_proof_params(&proof));

    let mut proof_elements = Vec::new();
    proof_elements.extend_from_slice(&[
        U256::try_from_be_slice(&proof.base_trace_commitment).unwrap(),
        U256::try_from_be_slice(proof.extension_trace_commitment.as_ref().unwrap()).unwrap(),
        U256::try_from_be_slice(&proof.composition_trace_commitment).unwrap(),
    ]);
    for eval in &proof.execution_trace_ood_evals {
        proof_elements.push(to_montgomery(*eval));
    }
    for eval in &proof.composition_trace_ood_evals {
        println!("ood eval: {}", eval);
        proof_elements.push(to_montgomery(*eval));
    }
    for layer in &proof.fri_proof.layers {
        let commitment = U256::try_from_be_slice(&layer.commitment).unwrap();
        println!("layer commitment is {}", commitment);
        proof_elements.push(commitment);
    }
    let fri_remainder_coeffs = &proof.fri_proof.remainder_coeffs;
    println!("Fri remainder coeffs len: {}", fri_remainder_coeffs.len());
    for eval in fri_remainder_coeffs {
        println!("remainder eval: {}", eval);
        proof_elements.push(U256::from(to_montgomery(*eval)));
    }

    let mut remainder_bytes = Vec::new();

    remainder_bytes.extend(proof.pow_nonce.to_be_bytes());

    println!(
        "first item: {}",
        to_montgomery(proof.trace_queries.base_trace_values[0])
    );

    for val in &proof.trace_queries.base_trace_values {
        remainder_bytes.extend(to_montgomery(*val).to_be_bytes::<32>());
    }
    for val in &proof.trace_queries.extension_trace_values {
        remainder_bytes.extend(to_montgomery(*val).to_be_bytes::<32>());
    }
    for val in &proof.trace_queries.composition_trace_values {
        remainder_bytes.extend(to_montgomery(*val).to_be_bytes::<32>());
    }

    let base_trace_merkle_statement = get_merkle_statement_values(
        &proof.base_trace_commitment,
        proof.trace_queries.base_trace_proof.clone(),
        &metadata.query_positions,
    );
    let base_trace_merkle_view = fmt_array_items(&base_trace_merkle_statement.view);
    let base_trace_initials = base_trace_merkle_statement
        .initials
        .into_iter()
        .flat_map(|(idx, hash)| [U256::from(idx), hash])
        .collect::<Vec<_>>();
    let base_trace_merkle_initials = fmt_array_items(&base_trace_initials);
    let base_trace_merkle_height = base_trace_merkle_statement.height;
    let base_trace_merkle_root = base_trace_merkle_statement.root;

    let extension_trace_merkle_statement = get_merkle_statement_values(
        proof.extension_trace_commitment.as_ref().as_ref().unwrap(),
        proof.trace_queries.extension_trace_proof.clone().unwrap(),
        &metadata.query_positions,
    );
    let extension_trace_merkle_view = fmt_array_items(&extension_trace_merkle_statement.view);
    let extension_trace_initials = extension_trace_merkle_statement
        .initials
        .into_iter()
        .flat_map(|(idx, hash)| [U256::from(idx), hash])
        .collect::<Vec<_>>();
    let extension_trace_merkle_initials = fmt_array_items(&extension_trace_initials);
    let extension_trace_merkle_height = extension_trace_merkle_statement.height;
    let extension_trace_merkle_root = extension_trace_merkle_statement.root;

    let composition_trace_merkle_statement = get_merkle_statement_values(
        &proof.composition_trace_commitment,
        proof.trace_queries.composition_trace_proof.clone(),
        &metadata.query_positions,
    );
    let composition_trace_merkle_view = fmt_array_items(&composition_trace_merkle_statement.view);
    let composition_trace_initials = composition_trace_merkle_statement
        .initials
        .into_iter()
        .flat_map(|(idx, hash)| [U256::from(idx), hash])
        .collect::<Vec<_>>();
    let composition_trace_merkle_initials = fmt_array_items(&composition_trace_initials);
    let composition_trace_merkle_height = composition_trace_merkle_statement.height;
    let composition_trace_merkle_root = composition_trace_merkle_statement.root;

    let fri_folding_factor = proof.options.fri_folding_factor as usize;
    let query_positions = &metadata.query_positions;
    let fri_alphas = &metadata.fri_alphas;
    let fri_statements = match fri_folding_factor {
        2 => gen_fri_statements::<2>(query_positions, &proof, fri_alphas),
        4 => gen_fri_statements::<4>(query_positions, &proof, fri_alphas),
        8 => gen_fri_statements::<8>(query_positions, &proof, fri_alphas),
        16 => gen_fri_statements::<16>(query_positions, &proof, fri_alphas),
        _ => unreachable!(),
    };

    println!(
        "last statement root: {}",
        fri_statements.last().unwrap().root
    );

    println!("1st item {}", fri_statements[0].fri_queue[0]);
    println!("2nd item {}", fri_statements[0].fri_queue[1]);
    println!("3rd item {}", fri_statements[0].fri_queue[2]);
    println!("first queue hash {}", fri_statements[1].input_hash);

    remainder_bytes.extend(fri_statements[1].input_hash.to_be_bytes::<32>());
    remainder_bytes.extend(fri_statements[2].input_hash.to_be_bytes::<32>());
    remainder_bytes.extend(fri_statements[3].input_hash.to_be_bytes::<32>());
    remainder_bytes.extend(fri_statements[4].input_hash.to_be_bytes::<32>());
    remainder_bytes.extend(fri_statements[5].input_hash.to_be_bytes::<32>());

    let fri_statements = print_fri_statements(&fri_statements);
    // assert_eq!(first_fri_statements, fri_statements);

    let remainder_elements = remainder_bytes
        .chunks(32)
        .map(|chunk| {
            let mut bytes32 = [0u8; 32];
            bytes32[0..chunk.len()].copy_from_slice(chunk);
            U256::try_from_be_slice(&bytes32).unwrap()
        })
        .collect::<Vec<_>>();

    println!("items len: {}", remainder_elements.len());

    proof_elements.extend(remainder_elements);

    // for val in proof.trace_queries.extension_trace_values {
    //     proof_elements.push(U256::from::<BigUint>(val.into()))
    // }

    let proof_elements = fmt_array_items(&proof_elements);

    res += &format!(
        r"// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

contract AutoGenProofData {{
    function getProofParams() public view returns (uint256[] memory) {{
        return proofParams;
    }}

    function getProof() public view returns (uint256[] memory) {{
        return proof;
    }}

    function getTaskMetadata() public view returns (uint256[] memory) {{
        return taskMetadata;
    }}

    function getCairoAuxInput() public view returns (uint256[] memory) {{
        return cairoAuxInput;
    }}

    function getBaseTraceMerkleView() public view returns (uint256[] memory) {{
        return baseTraceMerkleView;
    }}

    function getBaseTraceMerkleInitials() public view returns (uint256[] memory) {{
        return baseTraceMerkleInitials;
    }}

    function getExtensionTraceMerkleView() public view returns (uint256[] memory) {{
        return extensionTraceMerkleView;
    }}

    function getExtensionTraceMerkleInitials() public view returns (uint256[] memory) {{
        return extensionTraceMerkleInitials;
    }}

    function getCompositionTraceMerkleView() public view returns (uint256[] memory) {{
        return compositionTraceMerkleView;
    }}

    function getCompositionTraceMerkleInitials() public view returns (uint256[] memory) {{
        return compositionTraceMerkleInitials;
    }}

    function getFriDataLayers() public view returns (FriDataLayer[] memory) {{
        return friDataLayers;
    }}

    uint256 public cairoVerifierId = 6;

    uint256[] public proofParams = {proof_params};

    uint256[] public proof = {proof_elements};

    uint256[] public taskMetadata = [0];

    uint256[] public cairoAuxInput = {fmt_cairo_aux_inputs};

    uint256[] public baseTraceMerkleView = {base_trace_merkle_view};

    uint256[] public baseTraceMerkleInitials = {base_trace_merkle_initials};

    uint256 public baseTraceMerkleHeight = {base_trace_merkle_height};

    uint256 public baseTraceMerkleRoot = {base_trace_merkle_root};

    uint256[] public extensionTraceMerkleView = {extension_trace_merkle_view};

    uint256[] public extensionTraceMerkleInitials = {extension_trace_merkle_initials};

    uint256 public extensionTraceMerkleHeight = {extension_trace_merkle_height};

    uint256 public extensionTraceMerkleRoot = {extension_trace_merkle_root};

    uint256[] public compositionTraceMerkleView = {composition_trace_merkle_view};

    uint256[] public compositionTraceMerkleInitials = {composition_trace_merkle_initials};

    uint256 public compositionTraceMerkleHeight = {composition_trace_merkle_height};

    uint256 public compositionTraceMerkleRoot = {composition_trace_merkle_root};

    FriDataLayer[] public friDataLayers;

    constructor() public {{
        {fri_statements}
    }}
}}

contract FriDataLayer {{
    uint256[] public proof;
    uint256[] public friQueue;
    uint256 public evalPoint;
    uint256 public stepSize;
    uint256 public root;

    constructor(
            uint256[] memory _proof, 
            uint256[] memory _friQueue, 
            uint256 _evalPoint, 
            uint256 _stepSize, 
            uint256 _root
    ) public {{
        proof = _proof;
        friQueue = _friQueue;
        evalPoint = _evalPoint;
        stepSize = _stepSize;
        root = _root;
    }}

    function getQueue() public view returns (uint256[] memory) {{
        return friQueue;
    }}

    function getProof() public view returns (uint256[] memory) {{
        return proof;
    }}
}}
",
    );

    res
}

// NOTE: appears a merkle statement looks like this:
// `keccak(idx0 || leaf0 || idx1 || leaf1 || ... || root)`

struct BatchMerkleProofValues {
    root: U256,
    view: Vec<U256>,
    initials: Vec<(usize, U256)>,
    height: u32,
}

fn get_merkle_statement_values(
    root: &SerdeOutput<Keccak256>,
    proof: LeafVariantMerkleTreeProof<MaskedKeccak256HashFn<20>>,
    indices: &[usize],
) -> BatchMerkleProofValues {
    let nodes: Vec<SerdeOutput<Keccak256>>;
    let height: u32;
    let mut leaf_siblings = Vec::new();
    let mut initial_leaves = Vec::new();
    match proof {
        LeafVariantMerkleTreeProof::Hashed(proof) => {
            height = proof.height;
            nodes = proof.nodes;
            for leaf in proof.initial_leaves {
                initial_leaves.push(U256::try_from_be_slice(&leaf).unwrap())
            }
            for sibling in proof.sibling_leaves {
                leaf_siblings.push(U256::try_from_be_slice(&sibling).unwrap())
            }
        }
        LeafVariantMerkleTreeProof::Unhashed(proof) => {
            height = proof.height;
            nodes = proof.nodes;
            for leaf in proof.initial_leaves {
                let num = to_montgomery(leaf);
                initial_leaves.push(num)
            }
            for sibling in proof.sibling_leaves {
                let num = to_montgomery(sibling);
                leaf_siblings.push(num)
            }
        }
    }

    let nodes = nodes
        .into_iter()
        .map(|digest| U256::try_from_be_slice(&digest).unwrap())
        .collect::<Vec<U256>>();

    let shift = 1 << height;
    let adjusted_indices = indices.iter().map(|i| i + shift);

    BatchMerkleProofValues {
        root: U256::try_from_be_slice(root).unwrap(),
        view: [leaf_siblings, nodes].concat(),
        initials: zip(adjusted_indices, initial_leaves).collect(),
        height,
    }
}

/// Pretty prints a solidity array
fn fmt_array_items(items: &[impl Display]) -> String {
    let mut res = String::new();
    res += "[";
    let num_items = items.len();
    for (i, item) in items.iter().enumerate() {
        if i == num_items - 1 {
            res += &format!("{item}");
        } else {
            res += &format!("{item},");
        }
    }
    res += "]";
    res
}

fn gen_fri_statements<const N: usize>(
    initial_indices: &[usize],
    proof: &SharpProof,
    fri_alphas: &[Fp],
) -> Vec<FriLayerStatement> {
    let mut positions = initial_indices.to_vec();
    let mut domain_size = proof.trace_len * proof.options.lde_blowup_factor as usize;
    let mut res = Vec::new();
    let num_layers = proof.fri_proof.layers.len();
    println!("num layers: {num_layers}");
    for (layer, &alpha) in zip(&proof.fri_proof.layers, fri_alphas) {
        let folded_positions = fold_positions(&positions, N);
        let (chunks, _) = layer.flattenend_rows.as_chunks::<N>();
        let evals = get_query_values(chunks, &positions, &folded_positions);
        let fri_layer_statement =
            gen_fri_layer_statement::<N>(&positions, &evals, layer, domain_size, alpha);
        res.push(fri_layer_statement);
        positions = folded_positions;
        domain_size /= N;
    }
    res
}

fn print_fri_statements(statements: &[FriLayerStatement]) -> String {
    let mut res = vec![];

    let n = statements.len();
    res.push(format!(
        "FriDataLayer[] memory _friDataLayers = new FriDataLayer[]({n});"
    ));

    for (i, statement) in statements.iter().enumerate() {
        let proof_items = gen_uint256_array("proofItems", &statement.proof);
        let queue_items = gen_uint256_array("queueItems", &statement.fri_queue);
        let root = statement.root;
        let step_size = statement.step_size;
        let eval_point = statement.eval_point;
        res.push(format!(
            r"
            {{
                {proof_items}
                {queue_items}
                uint256 root = {root};
                uint256 evalPoint = {eval_point};
                uint256 stepSize = {step_size};
                _friDataLayers[{i}] = new FriDataLayer(proofItems, queueItems, evalPoint, stepSize, root);
            }}
        "
        ))
    }
    res.push("friDataLayers = _friDataLayers;".to_string());
    res.join("\n")
}

fn gen_uint256_array(variable_name: &str, items: &[U256]) -> String {
    let n = items.len();
    let mut res = vec![format!(
        "uint256[] memory {variable_name} = new uint256[]({n});"
    )];
    for (i, item) in items.iter().enumerate() {
        res.push(format!("{variable_name}[{i}] = {item};"));
    }
    res.join("\n")
}

fn get_proof_params(proof: &SharpProof) -> Vec<U256> {
    let options = proof.options;
    const N_QUERIES_OFFSET: usize = 0;
    const LOG_BLOWUP_FACTOR_OFFSET: usize = 1;
    const PROOF_OF_WORK_BITS_OFFSET: usize = 2;
    const FRI_LAST_LAYER_LOG_DEG_BOUND_OFFSET: usize = 3;
    const N_FRI_STEPS_OFFSET: usize = 4;

    let fri_options = options.into_fri_options();
    // fri_options.max_remainder_size;

    let lde_domain_size = proof.trace_len * options.lde_blowup_factor as usize;
    let folding_factor = U256::from(options.fri_folding_factor.ilog2());
    let fri_steps = [
        vec![uint!(0_U256)],
        vec![folding_factor; fri_options.num_layers(lde_domain_size)],
    ]
    .concat();

    let fri_last_layer_log_deg_bound =
        (fri_options.remainder_size(lde_domain_size) / options.lde_blowup_factor as usize).ilog2();

    let base_vals = {
        const NUM_VALS: usize = N_FRI_STEPS_OFFSET + 1;
        let mut vals = [U256::ZERO; NUM_VALS];
        vals[N_QUERIES_OFFSET] = U256::from(options.num_queries);
        vals[LOG_BLOWUP_FACTOR_OFFSET] = U256::from(options.lde_blowup_factor.ilog2());
        vals[PROOF_OF_WORK_BITS_OFFSET] = U256::from(options.grinding_factor);
        vals[FRI_LAST_LAYER_LOG_DEG_BOUND_OFFSET] = U256::from(fri_last_layer_log_deg_bound);
        vals[N_FRI_STEPS_OFFSET] = U256::from(fri_steps.len());
        vals.to_vec()
    };

    [base_vals, fri_steps].concat()
}
