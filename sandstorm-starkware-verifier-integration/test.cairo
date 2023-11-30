%builtins output pedersen range_check ecdsa bitwise ec_op keccak poseidon

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.cairo_keccak.keccak import cairo_keccak_uint256s_bigend, finalize_keccak
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.cairo_secp.ec import EcPoint
from starkware.cairo.common.cairo_secp.bigint import BigInt3, uint256_to_bigint
from starkware.cairo.common.cairo_secp.signature import public_key_point_to_eth_address
from starkware.cairo.common.uint256 import Uint256, felt_to_uint256

func proof{output_ptr: felt*,pedersen_ptr: HashBuiltin*,range_check_ptr,ecdsa_ptr,bitwise_ptr: BitwiseBuiltin*,ec_op_ptr,poseidon_ptr}(nonce: felt, hash: Uint256) -> () {
    alloc_locals;
    let (keccak_ptr: felt*) = alloc();
    local keccak_ptr_start: felt* = keccak_ptr;

    local x_high;
    %{ ids.x_high = program_input['x_high'] %}
    local x_low;
    %{ ids.x_low = program_input['x_low'] %}
    local y_high;
    %{ ids.y_high = program_input['y_high'] %}
    local y_low;
    %{ ids.y_low = program_input['y_low'] %}

    let public_key_x_bigint3: BigInt3 = uint256_to_bigint(x=Uint256(low=x_low, high=x_high));
    let public_key_y_bigint3: BigInt3 = uint256_to_bigint(x=Uint256(low=y_low, high=y_high));

    let public_key: EcPoint = EcPoint(public_key_x_bigint3, public_key_y_bigint3);

    with keccak_ptr {
        let (local cal_eth_address: felt) = public_key_point_to_eth_address(
            public_key_point=public_key
        );
        let address_uint256 = felt_to_uint256(cal_eth_address);
        let nonce_uint256 = felt_to_uint256(nonce);
        let (local arr: Uint256*) = alloc();
        assert arr[0] = address_uint256;
        assert arr[1] = nonce_uint256;
        let (local cal_hash: Uint256) = cairo_keccak_uint256s_bigend(n_elements=2, elements=arr);
        finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);
    }

    assert hash = cal_hash;

    return ();
}

func main{output_ptr: felt*,pedersen_ptr: HashBuiltin*,range_check_ptr,ecdsa_ptr,bitwise_ptr: BitwiseBuiltin*,ec_op_ptr,keccak_ptr,poseidon_ptr}() -> () {
    alloc_locals;
    local nonce;
    %{ ids.nonce = program_input['nonce'] %}
    assert [output_ptr] = nonce;
    local hash_high;
    %{ ids.hash_high = program_input['hash_high'] %}
    assert [output_ptr + 1] = hash_high;
    local hash_low;
    %{ ids.hash_low = program_input['hash_low'] %}
    assert [output_ptr + 2] = hash_low;

    let hash = Uint256(low=[output_ptr + 2], high=[output_ptr + 1]);
    proof(nonce=[output_ptr], hash=hash);

    let output_ptr = output_ptr + 3;
    return ();
}
