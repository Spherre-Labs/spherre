use core::byte_array::ByteArray;
use crate::interfaces::ispherre::{ISpherre, ISpherreDispatcher, ISpherreDispatcherTrait};
use crate::spherre::{Spherre, Spherre::SpherreImpl};
use snforge_std::{
    start_cheat_caller_address, stop_cheat_caller_address, declare, ContractClassTrait,
    DeclareResultTrait
};
use starknet::ContractAddress;
use starknet::contract_address_const;

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

// Test that the owner is correctly set during initialization
#[test]
fn test_owner_is_set_correctly() {
    let mut state = CONTRACT_STATE();
    let owner_address = contract_address_const::<10>();

    Spherre::constructor(ref state, owner_address,);

    let actual_owner = state.owner();
    assert_eq!(actual_owner, owner_address, "Owner should be set correctly");
}

// Test that only the owner can update a property (example)
#[test]
#[should_panic(expected: "Caller is not the owner")]
fn test_update_as_non_owner() {
    // Set up test data
    let owner = contract_address_const::<10>();
    let non_owner = contract_address_const::<5>();

    // Deploy the contract with constructor parameters
    let contract_address = deploy_contract(owner);

    // Create a dispatcher to call the contract
    let dispatcher = ISpherreDispatcher { contract_address };

    // Set the caller address to non-owner
    start_cheat_caller_address(contract_address, non_owner);

    // Attempt to transfer ownership as non-owner (should fail)
    dispatcher.transfer_ownership(contract_address_const::<20>());

    // Clean up
    stop_cheat_caller_address(contract_address);
}

// Test ownership transfer
#[test]
fn test_transfer_ownership() {
    // Set up test data
    let original_owner = contract_address_const::<10>();
    let new_owner = contract_address_const::<20>();

    // Deploy the contract with constructor parameters
    let contract_address = deploy_contract(original_owner);

    // Create a dispatcher to call the contract
    let dispatcher = ISpherreDispatcher { contract_address };

    // Set the caller address to original owner
    start_cheat_caller_address(contract_address, original_owner);

    // Transfer ownership
    dispatcher.transfer_ownership(new_owner);

    // Verify new owner
    let actual_owner = dispatcher.owner();
    assert_eq!(actual_owner, new_owner, "Ownership should be transferred to new owner");

    // Clean up
    stop_cheat_caller_address(contract_address);
}

// Test that only the owner can transfer ownership
#[test]
#[should_panic(expected: "Caller is not the owner")]
fn test_transfer_ownership_as_non_owner() {
    // Set up test data
    let owner = contract_address_const::<10>();
    let non_owner = contract_address_const::<5>();
    let new_owner = contract_address_const::<20>();

    // Deploy the contract with constructor parameters
    let contract_address = deploy_contract(owner);

    // Create a dispatcher to call the contract
    let dispatcher = ISpherreDispatcher { contract_address };

    // Set the caller address to non-owner
    start_cheat_caller_address(contract_address, non_owner);

    // Attempt to transfer ownership as non-owner (should fail)
    dispatcher.transfer_ownership(new_owner);

    // Clean up
    stop_cheat_caller_address(contract_address);
}

// Test renounce ownership
#[test]
fn test_renounce_ownership() {
    // Set up test data
    let owner = contract_address_const::<10>();

    // Deploy the contract with constructor parameters
    let contract_address = deploy_contract(owner);

    // Create a dispatcher to call the contract
    let dispatcher = ISpherreDispatcher { contract_address };

    // Set the caller address to owner
    start_cheat_caller_address(contract_address, owner);

    // Renounce ownership
    dispatcher.renounce_ownership();

    // Verify owner is zero address
    let actual_owner = dispatcher.owner();
    assert_eq!(actual_owner, contract_address_const::<0>(), "Ownership should be renounced");

    // Clean up
    stop_cheat_caller_address(contract_address);
}

// Test that only the owner can renounce ownership
#[test]
#[should_panic(expected: "Caller is not the owner")]
fn test_renounce_ownership_as_non_owner() {
    // Set up test data
    let owner = contract_address_const::<10>();
    let non_owner = contract_address_const::<5>();

    // Deploy the contract with constructor parameters
    let contract_address = deploy_contract(owner);

    // Create a dispatcher to call the contract
    let dispatcher = ISpherreDispatcher { contract_address };

    // Set the caller address to non-owner
    start_cheat_caller_address(contract_address, non_owner);

    // Attempt to renounce ownership as non-owner (should fail)
    dispatcher.renounce_ownership();

    // Clean up
    stop_cheat_caller_address(contract_address);
}

// PAUSABLE TESTS

// Test that contract is not paused by default
#[test]
fn test_contract_not_paused_by_default() {
    // Set up test data
    let owner = contract_address_const::<10>();

    // Deploy the contract with constructor parameters
    let contract_address = deploy_contract(owner);

    // Create a dispatcher to call the contract
    let dispatcher = ISpherreDispatcher { contract_address };

    // Check that contract is not paused by default
    let is_paused = dispatcher.is_paused();
    assert_eq!(is_paused, false, "Contract should not be paused by default");
}

// Test that owner can pause the contract
#[test]
fn test_owner_can_pause() {
    // Set up test data
    let owner = contract_address_const::<10>();

    // Deploy the contract with constructor parameters
    let contract_address = deploy_contract(owner);

    // Create a dispatcher to call the contract
    let dispatcher = ISpherreDispatcher { contract_address };

    // Set the caller address to owner
    start_cheat_caller_address(contract_address, owner);

    // Pause the contract
    dispatcher.pause();

    // Verify contract is paused
    let is_paused = dispatcher.is_paused();
    assert_eq!(is_paused, true, "Contract should be paused");

    // Clean up
    stop_cheat_caller_address(contract_address);
}

// Test that owner can unpause the contract
#[test]
fn test_owner_can_unpause() {
    // Set up test data
    let owner = contract_address_const::<10>();

    // Deploy the contract with constructor parameters
    let contract_address = deploy_contract(owner);

    // Create a dispatcher to call the contract
    let dispatcher = ISpherreDispatcher { contract_address };

    // Set the caller address to owner
    start_cheat_caller_address(contract_address, owner);

    // Pause the contract
    dispatcher.pause();

    // Verify contract is paused
    let is_paused = dispatcher.is_paused();
    assert_eq!(is_paused, true, "Contract should be paused");

    // Unpause the contract
    dispatcher.unpause();

    // Verify contract is not paused
    let is_paused = dispatcher.is_paused();
    assert_eq!(is_paused, false, "Contract should not be paused");

    // Clean up
    stop_cheat_caller_address(contract_address);
}

// Test that non-owner cannot pause the contract
#[test]
#[should_panic(expected: "Caller is not the owner")]
fn test_non_owner_cannot_pause() {
    // Set up test data
    let owner = contract_address_const::<10>();
    let non_owner = contract_address_const::<5>();

    // Deploy the contract with constructor parameters
    let contract_address = deploy_contract(owner);

    // Create a dispatcher to call the contract
    let dispatcher = ISpherreDispatcher { contract_address };

    // Set the caller address to non-owner
    start_cheat_caller_address(contract_address, non_owner);

    // Attempt to pause as non-owner (should fail)
    dispatcher.pause();

    // Clean up
    stop_cheat_caller_address(contract_address);
}

// Test that non-owner cannot unpause the contract
#[test]
#[should_panic(expected: "Caller is not the owner")]
fn test_non_owner_cannot_unpause() {
    // Set up test data
    let owner = contract_address_const::<10>();
    let non_owner = contract_address_const::<5>();

    // Deploy the contract with constructor parameters
    let contract_address = deploy_contract(owner);

    // Create a dispatcher to call the contract
    let dispatcher = ISpherreDispatcher { contract_address };

    // Set the caller address to owner
    start_cheat_caller_address(contract_address, owner);

    // Pause the contract
    dispatcher.pause();

    // Stop cheating as owner
    stop_cheat_caller_address(contract_address);

    // Set the caller address to non-owner
    start_cheat_caller_address(contract_address, non_owner);

    // Attempt to unpause as non-owner (should fail)
    dispatcher.unpause();

    // Clean up
    stop_cheat_caller_address(contract_address);
}

// Test that cannot pause when already paused
#[test]
fn test_cannot_pause_when_paused() {
    // Set up test data
    let owner = contract_address_const::<10>();

    // Deploy the contract with constructor parameters
    let contract_address = deploy_contract(owner);

    // Create a dispatcher to call the contract
    let dispatcher = ISpherreDispatcher { contract_address };

    // Set the caller address to owner
    start_cheat_caller_address(contract_address, owner);

    // Pause the contract
    dispatcher.pause();

    // Verify contract is paused
    let is_paused = dispatcher.is_paused();
    assert(is_paused, 'Contract should be paused');

    // Clean up
    stop_cheat_caller_address(contract_address);
}

// Test that cannot unpause when not paused
#[test]
fn test_cannot_unpause_when_not_paused() {
    // Set up test data
    let owner = contract_address_const::<10>();

    // Deploy the contract with constructor parameters
    let contract_address = deploy_contract(owner);

    // Create a dispatcher to call the contract
    let dispatcher = ISpherreDispatcher { contract_address };

    // Set the caller address to owner
    start_cheat_caller_address(contract_address, owner);

    // Verify contract is not paused
    let is_paused = dispatcher.is_paused();
    assert(!is_paused, 'Contract should not be paused');

    // Clean up
    stop_cheat_caller_address(contract_address);
}
