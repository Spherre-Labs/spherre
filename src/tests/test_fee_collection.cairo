use crate::account::{SpherreAccount};
use crate::interfaces::iaccount::{IAccountDispatcher, IAccountDispatcherTrait};
use crate::interfaces::iaccount_data::{IAccountDataDispatcher, IAccountDataDispatcherTrait};
use crate::interfaces::ispherre::{ISpherreDispatcher, ISpherreDispatcherTrait};
use crate::spherre::Spherre::Event::{AccountClassHashUpdated};
use crate::spherre::Spherre::{SpherreImpl};
use crate::spherre::Spherre;
use openzeppelin::access::accesscontrol::{DEFAULT_ADMIN_ROLE, AccessControlComponent};
use snforge_std::{
    start_cheat_caller_address, stop_cheat_caller_address, declare, ContractClassTrait, spy_events,
    EventSpyAssertionsTrait, DeclareResultTrait, get_class_hash
};
use spherre::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use spherre::tests::mocks::mock_token::{IMockTokenDispatcher, IMockTokenDispatcherTrait};
use spherre::types::{FeesType, SpherreAdminRoles};
use starknet::class_hash::class_hash_const;
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

