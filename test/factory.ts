import { expect } from "chai";
import { ethers } from "hardhat";
import {deployAll} from './utils'

describe("Factory", function () {
  it("can't create the an instance for the same token twice", async function () {
    const { llamaPay, llamaPayFactory, token } = await deployAll({})
    await expect(
      llamaPayFactory.createLlamaPayContract(token.address)
    ).to.be.revertedWith("");
  });

  it("array works", async function () {
    let tokens = [
      "0xdac17f958d2ee523a2206206994597c13d831ec7",
      "0xB8c77482e45F1F44dE1745F52C74426C631bDD52",
      "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
      "0x2b591e99afe9f32eaa6214f7b7629768c40eeb39"
    ]
    const { llamaPay, llamaPayFactory, token } = await deployAll({});
    for(const tokenAddress of tokens){
      expect((await llamaPayFactory.getLlamaPayContractByToken(tokenAddress)).isDeployed).to.equal(false)
      await llamaPayFactory.createLlamaPayContract(tokenAddress);
    }
    expect(await llamaPayFactory.getLlamaPayContractCount()).to.equal((tokens.length+1).toString())
    tokens = [token.address].concat(tokens)
    for(let i =0; i<tokens.length; i++){
      expect(await llamaPayFactory.getLlamaPayContractByIndex(i)).not.to.equal("0x0000000000000000000000000000000000000000");
      expect((await llamaPayFactory.getLlamaPayContractByToken(tokens[i])).isDeployed).to.equal(true)
    }
  });
});
