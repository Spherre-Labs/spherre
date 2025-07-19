use crate::account::{SpherreAccount, SpherreAccount::AccountImpl};
use crate::types::AccountDetails;
use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
use starknet::contract_address_const;
use starknet::{storage::{StorableStoragePointerReadAccess}};

// setting up the contract state
fn CONTRACT_STATE() -> SpherreAccount::ContractState {
    SpherreAccount::contract_state_for_testing()
}

fn init_contract() -> SpherreAccount::ContractState {
    let mut state = SpherreAccount::contract_state_for_testing();
    SpherreAccount::constructor(
        ref state,
        contract_address_const::<2>(), // deployer
        contract_address_const::<2>(), // owner (same as deployer)
        "TestAccount", // name
        "TestDescription", // description
        array![contract_address_const::<3>()], // members
        1 // threshold
    );
    state
}

// Validate Deployer Address
// This test ensures that the deployer address is not set to zero.
// If the deployer address is zero, contract deployment should fail.
#[test]
#[should_panic(expected: 'Deployer should not be zero')]
fn test_deployer_is_not_zero_address() {
    let mut state = CONTRACT_STATE();
    SpherreAccount::constructor(
        ref state,
        contract_address_const::<0>(),
        contract_address_const::<0>(),
        "John Doe",
        "John Does's Sphere",
        array![],
        4,
    );
}

// Validate Owner Address
// This test checks that the owner address is not zero.
// The owner must have a valid address to manage the contract.
#[test]
#[should_panic(expected: 'Owner should not be zero')]
fn test_owner_is_not_zero_address() {
    let mut state = CONTRACT_STATE();
    SpherreAccount::constructor(
        ref state,
        contract_address_const::<2>(),
        contract_address_const::<0>(),
        "John Doe",
        "John Does's Sphere",
        array![],
        4,
    );
}

// Validate Member Threshold
// This test verifies that the number of members is not less than the threshold.
// The contract should require at least `threshold` members to function correctly.
#[test]
#[should_panic(expected: 'Members must meet threshold')]
fn test_members_meet_threshold() {
    let mut state = CONTRACT_STATE();
    SpherreAccount::constructor(
        ref state,
        contract_address_const::<2>(),
        contract_address_const::<10>(),
        "John Doe",
        "John Does's Sphere",
        array![contract_address_const::<4>(), contract_address_const::<5>()],
        4,
    );
}

// Validate Name Assignment
// This test confirms that the contract name is correctly stored in `self.name`.
// The provided name should match what was set during deployment.
#[test]
fn test_name_is_set_correctly() {
    let mut state = CONTRACT_STATE();
    let set_name: ByteArray = "John Doe";
    let set_description: ByteArray = "John Does's Sphere";
    SpherreAccount::constructor(
        ref state,
        contract_address_const::<2>(),
        contract_address_const::<10>(),
        set_name,
        set_description,
        array![contract_address_const::<4>(), contract_address_const::<5>()],
        2,
    );
    let actual_name: ByteArray = state.get_name();
    assert_eq!(actual_name, "John Doe");
}

// Validate Description Assignment
// This test ensures that the contract description is properly stored in `self.description`.
// The description should be retrievable as expected.
#[test]
fn test_description_is_set_correctly() {
    let mut state = CONTRACT_STATE();
    let new_name: ByteArray = "John Doe";
    let set_description: ByteArray = "John Does's Sphere";
    SpherreAccount::constructor(
        ref state,
        contract_address_const::<2>(),
        contract_address_const::<10>(),
        new_name,
        set_description,
        array![contract_address_const::<4>(), contract_address_const::<5>()],
        2,
    );
    let actual_description: ByteArray = state.get_description();
    assert_eq!(actual_description, "John Does's Sphere");
}


#[test]
fn test_get_account_details() {
    let mut state = CONTRACT_STATE();
    let set_name: ByteArray = "John Doe";
    let set_description: ByteArray = "John Does's Sphere";
    SpherreAccount::constructor(
        ref state,
        contract_address_const::<2>(),
        contract_address_const::<10>(),
        set_name,
        set_description,
        array![contract_address_const::<4>(), contract_address_const::<5>()],
        2,
    );

    let account_details: AccountDetails = state.get_account_details();
    assert_eq!(account_details.name, "John Doe");
    assert_eq!(account_details.description, "John Does's Sphere");
}
#[test]
fn test_deployer_storage() {
    let deployer = contract_address_const::<2>();
    let mut state = CONTRACT_STATE();

    SpherreAccount::constructor(
        ref state,
        deployer,
        contract_address_const::<10>(),
        "Test",
        "Desc",
        array![contract_address_const::<3>()],
        1,
    );

    assert(state.get_deployer() == deployer, 'Deployer not stored correctly');
}
#[test]
#[should_panic(expected: 'Caller is not deployer')]
fn test_non_deployer_cannot_pause() {
    let mut state = init_contract();
    let non_deployer = contract_address_const::<3>();

    start_cheat_caller_address(state.contract_address.read(), non_deployer);
    state.pause(); // Now works with proper imports
}

#[test]
#[should_panic(expected: 'Caller is not deployer')]
fn test_non_deployer_cannot_unpause() {
    let mut state = init_contract();
    let deployer = contract_address_const::<2>();
    let non_deployer = contract_address_const::<3>();

    // Pause first as deployer
    start_cheat_caller_address(state.contract_address.read(), deployer);
    state.pause();
    stop_cheat_caller_address(state.contract_address.read());

    // Try unpause as non-deployer
    start_cheat_caller_address(state.contract_address.read(), non_deployer);
    state.unpause();
}
