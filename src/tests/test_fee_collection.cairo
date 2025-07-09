use crate::interfaces::iaccount_data::{IAccountDataDispatcher, IAccountDataDispatcherTrait};
use crate::interfaces::ispherre::{ISpherreDispatcher, ISpherreDispatcherTrait};
use crate::spherre::Spherre::{SpherreImpl};
use crate::spherre::Spherre;
use snforge_std::{
    start_cheat_caller_address, stop_cheat_caller_address, declare, ContractClassTrait, spy_events,
    EventSpyAssertionsTrait, DeclareResultTrait,
};
use spherre::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use spherre::interfaces::itoken_tx::{ITokenTransactionDispatcher, ITokenTransactionDispatcherTrait};
use spherre::tests::mocks::mock_token::{IMockTokenDispatcher, IMockTokenDispatcherTrait};
use spherre::types::{FeesType};
use starknet::{ContractAddress, contract_address_const, ClassHash,};


// Define role constants for testing
const PROPOSER_ROLE: felt252 = 'PR';
const EXECUTOR_ROLE: felt252 = 'ER';
const VOTER_ROLE: felt252 = 'VR';

// Setting up the contract state
fn CONTRACT_STATE() -> Spherre::ContractState {
    Spherre::contract_state_for_testing()
}

// Helper function to deploy a contract for testing
fn deploy_contract(owner: ContractAddress) -> ContractAddress {
    let contract_class = declare("Spherre").unwrap().contract_class();

    // Start with basic parameters
    let mut calldata = array![owner.into()];

    // The deploy method returns a tuple (ContractAddress, Span<felt252>)
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    contract_address
}

fn deploy_mock_token() -> IERC20Dispatcher {
    let contract_class = declare("MockToken").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IERC20Dispatcher { contract_address }
}

// deploy spherre account to get classhash
fn get_spherre_account_class_hash() -> ClassHash {
    let contract_class = declare("SpherreAccount").unwrap().contract_class();
    contract_class.class_hash.clone()
}

fn OWNER() -> ContractAddress {
    contract_address_const::<'Owner'>()
}
fn MEMBER_ONE() -> ContractAddress {
    contract_address_const::<'Member_one'>()
}
fn MEMBER_TWO() -> ContractAddress {
    contract_address_const::<'Member_two'>()
}

fn cheat_set_account_class_hash(
    contract_address: ContractAddress, new_hash: ClassHash, superadmin: ContractAddress,
) {
    start_cheat_caller_address(contract_address, superadmin);
    ISpherreDispatcher { contract_address }.update_account_class_hash(new_hash);
    stop_cheat_caller_address(contract_address);
}
// TODO: figure out why insufficient balance assertion is called and
// why the test is failing.

// #[test]
// fn test_fee_collection_successfull() {
//     let spherre_contract = deploy_contract(OWNER());
//     let spherre_dispatcher = ISpherreDispatcher { contract_address: spherre_contract };
//     let owner = OWNER();
//     let token = deploy_mock_token();
//     let fee: u256 = 10000;
//     let amount_to_propose: u256 = 1000000;
//     let receiver: ContractAddress = contract_address_const::<'recipient'>();
//     // Set classhash
//     let classhash: ClassHash = get_spherre_account_class_hash();
//     cheat_set_account_class_hash(spherre_contract, classhash, owner);
//     // Update the fees token and fee
//     start_cheat_caller_address(spherre_contract, owner);
//     spherre_dispatcher.update_fee_token(token.contract_address);
//     spherre_dispatcher.update_fee(FeesType::PROPOSAL_FEE, fee);
//     stop_cheat_caller_address(spherre_contract);
//     // Check if fee token is set
//     assert(
//         spherre_dispatcher.get_fee(FeesType::PROPOSAL_FEE, 1.try_into().unwrap()) == fee,
//         'Invalid fee'
//     );
//     assert(
//         spherre_dispatcher.get_fee_token() == token.contract_address,
//         'Invalid fee token'
//     );
//     // Call the deploy account function
//     let name: ByteArray = "Test Spherre Account";
//     let description: ByteArray = "Test Spherre Account Description";
//     let members: Array<ContractAddress> = array![owner, MEMBER_ONE(), MEMBER_TWO()];
//     let threshold: u64 = 2;
//     let account_address = spherre_dispatcher
//         .deploy_account(owner, name, description, members, threshold);
//     // Test newly deployed spherre contract
//     assert(spherre_dispatcher.is_deployed_account(account_address), 'Account not deployed');
//     let spherre_account_data_dispatcher = IAccountDataDispatcher {
//         contract_address: account_address
//     };
//     // Check that the account is deployed properly
//     assert(spherre_account_data_dispatcher.is_member(OWNER()), 'Not a member');

//     // Propose a transaction like a token transfer transaction
//     // But first, mint the token
//     let token = deploy_mock_token();
//     let mint_dispatcher = IMockTokenDispatcher{contract_address: token.contract_address};
//     let amount_to_mint: u256 = 100000000000000;
//     start_cheat_caller_address(account_address, owner);
//     mint_dispatcher.mint(owner, amount_to_mint);
//     // Mint for account address
//     mint_dispatcher.mint(account_address, amount_to_mint);
//     assert(
//         token.balance_of(owner) == amount_to_mint,
//         'Invalid mint balance'
//     );

//     // Propose the token transaction
//     let token_transaction_dispatcher = ITokenTransactionDispatcher{contract_address:
//     account_address};

//     token_transaction_dispatcher.propose_token_transaction(
//         token.contract_address,
//         amount_to_propose,
//         receiver
//     );
//     stop_cheat_caller_address(account_address);
//     // Start the checks
//     // Check whether the balance minted has changed
//     let expected_balance = amount_to_mint - fee;
//     assert(
//         token.balance_of(owner) == expected_balance,
//         'Invalid balance'
//     );
// }


