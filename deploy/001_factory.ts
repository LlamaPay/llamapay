import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre as any;
  const {deploy} = deployments;

  const {deployer} = await getNamedAccounts();

  await deploy('LlamaPayFactory', {
    from: deployer,
    args: [],
    log: true,
    autoMine: true, // speed up deployment on local network (ganache, hardhat), no effect on live networks
    deterministicDeployment: true,
  });
};
export default func;
func.tags = ['LlamaPayFactory'];