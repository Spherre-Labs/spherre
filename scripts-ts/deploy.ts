import {
  deployContract,
  executeDeployCalls,
  exportDeployments,
  deployer,
  networkName,
} from "./deploy-contract";
import { green, red, yellow } from "./helpers/colorize-log";
import { stark, constants } from "starknet";
import path from "path";
import fs from "fs";

const deployScript = async (): Promise<void> => {
  // Deploy the Spherre contract
  console.log(green("Deploying Spherre contract..."));
  let { address } = await deployContract({
    contract: "Spherre",
    constructorArgs: {
      owner: deployer.address,
    },
  });
  // Deploy a SpherreAccount contract to get the classhash for spherre main contract
  // The members
  let mockMembers = [
    deployer.address,
    stark.randomAddress(),
    stark.randomAddress(),
  ];
  // The threshold
  let threshold = 2;
  // Deploy the SpherreAccount contract
  console.log(green("Deploying SpherreAccount contract..."));
  let { classHash } = await deployContract({
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
const updateCallScript = async (): Promise<void> => {
  const filePath = path.resolve(
    __dirname,
    `../deployments/${networkName}_latest.json`
  );
  if (!fs.existsSync(filePath)) {
    console.log(
      red(`No deployment file found at ${filePath}. cannot update classHash`)
    );
    return;
  }
  const content: Record<
    string,
    {
      contract: string;
      address: string;
      classHash: string;
    }
  > = JSON.parse(fs.readFileSync(filePath, "utf8"));
  const spherreAccountClassHash = content["SpherreAccount"].classHash;
  const spherreAddress = content["Spherre"].address;
  // Update the Spherre contract with the classHash of the SpherreAccount contract
  console.log(
    yellow(
      "Adding SpherreAccount classHash to spherre contract for proxy deployment..."
    )
  );
  await deployer.execute(
    [
      {
        contractAddress: spherreAddress,
        entrypoint: "update_account_class_hash",
        calldata: [spherreAccountClassHash],
      },
    ],
    {
      version: constants.TRANSACTION_VERSION.V3,
    }
  );
  console.log(
    green("SpherreAccount classHash added to Spherre contract successfully!")
  );
};
const main = async (): Promise<void> => {
  try {
    await deployScript();
    await executeDeployCalls();
    exportDeployments();
    // Update ClassHash
    await updateCallScript();

    console.log(green("All Setup Done!"));
  } catch (err) {
    console.log(err);
    process.exit(1); //exit with error so that non subsequent scripts are run
  }
};

main();
