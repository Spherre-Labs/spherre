use crate::account::{SpherreAccount};
use crate::interfaces::iaccount::{IAccountDispatcher, IAccountDispatcherTrait};
use crate::interfaces::iaccount_data::{IAccountDataDispatcher, IAccountDataDispatcherTrait};
use crate::interfaces::ispherre::{ISpherre, ISpherreDispatcher, ISpherreDispatcherTrait};
use crate::spherre::{Spherre, Spherre::SpherreImpl};
use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
use snforge_std::{
    start_cheat_caller_address, stop_cheat_caller_address, declare, ContractClassTrait,
    DeclareResultTrait
};
use starknet::ContractAddress;
use starknet::contract_address_const;

// Define role constants for testing
const PROPOSER_ROLE: felt252 = 'PR';
const EXECUTOR_ROLE: felt252 = 'ER';
const VOTER_ROLE: felt252 = 'VR';

// Setting up the contract state
fn CONTRACT_STATE() -> Spherre::ContractState {
    Spherre::contract_state_for_testing()
}

// Helper function to deploy a contract for testing
fn deploy_contract(owner: ContractAddress,) -> ContractAddress {
    let contract_class = declare("Spherre").unwrap().contract_class();

    // Start with basic parameters
    let mut calldata = array![owner.into(),];

    // The deploy method returns a tuple (ContractAddress, Span<felt252>)
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    contract_address
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

// TODO: Wait for classhash setter function in order to conplete the test case

#[test]
fn test_deploy_account() {
    let spherre_contract = deploy_contract(OWNER());
    let spherre_dispatcher = ISpherreDispatcher { contract_address: spherre_contract };
    // Call the deploy account function
    let owner = OWNER();
    let name: ByteArray = "Test Spherre Account";
    let description: ByteArray = "Test Spherre Account Description";
    let members: Array<ContractAddress> = array![owner, MEMBER_ONE(), MEMBER_TWO()];
    let threshold: u64 = 2;
    let account_address = spherre_dispatcher
        .deploy_account(owner, name, description, members, threshold);
    // Test newly deployed spherre contract
    assert(spherre_dispatcher.is_deployed_account(account_address), 'Account not deployed');
    let spherre_account_data_dispatcher = IAccountDataDispatcher {
        contract_address: account_address
    };
    let spherre_account_dispatcher = IAccountDispatcher { contract_address: account_address };
    // Check member statuss
    assert(spherre_account_data_dispatcher.is_member(OWNER()), 'Not a member');
    // Check the threshold
    let (account_threshold, num_of_members) = spherre_account_data_dispatcher.get_threshold();
    assert(account_threshold == threshold, 'Invalid threshold');
    assert(num_of_members == 3, 'Invalid members number');
    // check name
    let account_name = spherre_account_dispatcher.get_name();
    assert(account_name == "Test Spherre Account", 'Invalid account name');

    let account_deployer = spherre_account_dispatcher.get_deployer();
    assert(account_deployer == spherre_contract, 'Invalid deployer');
}
