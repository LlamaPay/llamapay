import { ethers } from "hardhat";
import {deploy} from "../test/utils"

async function main() {
  const llamaPayFactory = await deploy("LlamaPayFactory")
  console.log("LlamaPayFactory deployed to:", llamaPayFactory.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
