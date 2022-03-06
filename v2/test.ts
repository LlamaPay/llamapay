import { expect } from "chai";
import { ethers } from "hardhat";

async function deploy(name:string, args:string[]=[]){
  const Contract = await ethers.getContractFactory(name);
    const contract = await Contract.deploy(...args);
    await contract.deployed();
    return contract
}

describe("LlamaPay", function () {
  it("getPricePerShare()", async function () {
    const yearnAdapter = await deploy("YearnAdapter");
    const llamaPay = await deploy("LlamaPay", 
      ["0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", yearnAdapter.address, "0xa258C4606Ca8206D8aA700cE2143D7db854D168c"]
    )

    const price = await llamaPay.getPricePerShare();
    console.log(price);
  });
});
