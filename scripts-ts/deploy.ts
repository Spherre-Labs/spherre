import {
  deployContract,
  executeDeployCalls,
  exportDeployments,
  deployer,
} from "./deploy-contract";
import { green } from "./helpers/colorize-log";
import { stark } from "starknet";


const deployScript = async (): Promise<void> => {
  // Deploy the Spherre contract
  let {address} = await deployContract({
    contract: "Spherre",
    constructorArgs: {
      owner: deployer.address,
    },
  });
  // Deploy a SpherreAccount contract to get the classhash
  // The members
  let mockMembers = [
    deployer.address,
    stark.randomAddress(),
    stark.randomAddress(),
  ];
  // The threshold
  let threshold = 2;
  // Deploy the SpherreAccount contract
  await deployContract({
    contract: "SpherreAccount",
    constructorArgs: {
      deployer: deployer.address,
      owner: deployer.address,
      name: "Initial account",
      description: "This is the initial account",
      members: mockMembers,
      threshold,
    },
  });
};

const main = async (): Promise<void> => {
  try {
    await deployScript();
    await executeDeployCalls();
    exportDeployments();

    console.log(green("All Setup Done!"));
  } catch (err) {
    console.log(err);
    process.exit(1); //exit with error so that non subsequent scripts are run
  }
};

main();
