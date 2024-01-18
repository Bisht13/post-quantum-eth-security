import ow from "ow";
import fs from "fs";

import {
  BundlerConfig,
  bundlerConfigDefault,
  BundlerConfigShape,
} from "./BundlerConfig";
import { Wallet, Signer } from "ethers";
import { BaseProvider, JsonRpcProvider } from "@ethersproject/providers";

function getCommandLineParams(programOpts: any): Partial<BundlerConfig> {
  const params: any = {};
  for (const bundlerConfigShapeKey in BundlerConfigShape) {
    const optionValue = programOpts[bundlerConfigShapeKey];
    if (optionValue != null) {
      params[bundlerConfigShapeKey] = optionValue;
    }
  }
  return params as BundlerConfig;
}

function mergeConfigs(
  ...sources: Array<Partial<BundlerConfig>>
): BundlerConfig {
  const mergedConfig = Object.assign({}, ...sources);
  ow(mergedConfig, ow.object.exactShape(BundlerConfigShape));
  return mergedConfig;
}

const DEFAULT_INFURA_ID = "bdabe9d2f9244005af0f566398e648da";

export function getNetworkProvider(url: string): JsonRpcProvider {
  if (url.match(/^[\w-]+$/) != null) {
    const infuraId = process.env.INFURA_ID1 ?? DEFAULT_INFURA_ID;
    url = `https://${url}.infura.io/v3/${infuraId}`;
  }
  // console.log("url=", url);
  // return new JsonRpcProvider("http://127.0.0.1:8545");
  return new JsonRpcProvider(url);
}

export async function resolveConfiguration(
  programOpts: any
): Promise<{ config: BundlerConfig; provider: BaseProvider; wallet: Signer }> {
  const commandLineParams = getCommandLineParams(programOpts);
  let fileConfig: Partial<BundlerConfig> = {};
  const configFileName = programOpts.config;
  if (fs.existsSync(configFileName)) {
    fileConfig = JSON.parse(fs.readFileSync(configFileName, "ascii"));
  }
  const config = mergeConfigs(
    bundlerConfigDefault,
    fileConfig,
    commandLineParams
  );
  console.log("Merged configuration:", JSON.stringify(config));

  if (config.network === "hardhat") {
    // eslint-disable-next-line
    const provider: JsonRpcProvider = require("hardhat").ethers.provider;
    return { config, provider, wallet: provider.getSigner() };
  }

  const provider: BaseProvider = getNetworkProvider(config.network);
  let mnemonic: string;
  let wallet: Wallet;
  try {
    mnemonic = fs.readFileSync(config.mnemonic, "ascii").trim();
    wallet = Wallet.fromMnemonic(mnemonic).connect(provider);
    // wallet = new Wallet(
    //   "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
    // ).connect(provider);
  } catch (e: any) {
    throw new Error(
      `Unable to read --mnemonic ${config.mnemonic}: ${e.message as string}`
    );
  }
  return { config, provider, wallet };
}
