var fs = require("fs");
var {
  Account,
  RpcProvider,
  constants,
  json,
  CallData,
  cairo,
  Contract,
} = require("starknet");
const dotenv = require("dotenv");

// Load environment variables from .env file
dotenv.config();

// Async function to handle the entire flow
async function deployERC1155() {
  // Initialize provider
  var provider = new RpcProvider({
    nodeUrl: constants.NetworkName.SN_SEPOLIA,
  });

  // Initialize existing pre-deployed account 0 of Devnet-rs
  var privateKey = process.env.STARKNET_PRIVATE_KEY;
  var accountAddress = process.env.STARKNET_ACCOUNT_ADDRESS;
  console.log(privateKey, accountAddress);

  var account0 = new Account(provider, accountAddress, privateKey);

  console.log("Deployment Tx - ERC1155 Contract to Starknet...");

  // Read and parse the compiled contract files
  var compiledSierra = json.parse(
    fs
      .readFileSync("./target/dev/morning_star_MyERC1155.contract_class.json")
      .toString("ascii")
  );
  var compiledCasm = json.parse(
    fs
      .readFileSync(
        "./target/dev/morning_star_MyERC1155.compiled_contract_class.json"
      )
      .toString("ascii")
  );

  // Define initial token supply
  var initialTk = cairo.uint256(20n * 10n ** 18n); // 20 NIT
  //   var erc20CallData = new CallData(compiledSierra.abi);
  var erc1155CallData = new CallData(compiledSierra.abi);

  var ERC1155ConstructorCallData = erc1155CallData.compile("constructor", {
    token_uri: "niceToken",
    recipient: account0.address,
    token_ids: [1, 2, 3, 4],
    values: [100, 200, 300, 400],
  });

  console.log("constructor=", ERC1155ConstructorCallData);

  // Declare and deploy the ER1155 contract
  try {
    var deployERC1155Response = await account0.declareAndDeploy({
      contract: compiledSierra,
      casm: compiledCasm,
      constructorCalldata: ERC1155ConstructorCallData,
    });

    console.log(
      "ERC1155 declared hash: ",
      deployERC1155Response.declare.class_hash
    );
    console.log(
      "ERC1155 deployed at address: ",
      deployERC1155Response.deploy.contract_address
    );

    // Get the erc1155 contract address
    var erc1155Address = deployERC1155Response.deploy.contract_address;

    // Create a new ERC1155 contract object
    var erc1155 = new Contract(compiledSierra.abi, erc1155Address, provider);

    // Connect the ERC1155 contract to the account
    erc1155.connect(account0);
  } catch (error) {
    console.error("Error deploying ERC1155 contract:", error);
  }
}

// Call the async function
deployERC1155();
