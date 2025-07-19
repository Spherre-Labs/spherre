use crate::interfaces::iaccount::{IAccountDispatcher, IAccountDispatcherTrait};
use crate::interfaces::iaccount_data::{IAccountDataDispatcher, IAccountDataDispatcherTrait};
use crate::interfaces::ispherre::{ISpherreDispatcher, ISpherreDispatcherTrait};

use crate::spherre::Spherre::{SpherreImpl};
use crate::spherre::Spherre;
use openzeppelin::access::accesscontrol::{AccessControlComponent};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address, start_cheat_block_timestamp,
    stop_cheat_block_timestamp,
};
use spherre::types::{FeesType};
use starknet::class_hash::class_hash_const;
use starknet::{ClassHash, ContractAddress, contract_address_const};


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

#[test]
fn test_deploy_account() {
    let spherre_contract = deploy_contract(OWNER());
    let spherre_dispatcher = ISpherreDispatcher { contract_address: spherre_contract };
    let owner = OWNER();
    // Set classhash
    let classhash: ClassHash = get_spherre_account_class_hash();
    cheat_set_account_class_hash(spherre_contract, classhash, owner);

    // Call the deploy account function

    let name: ByteArray = "Test Spherre Account";
    let description: ByteArray = "Test Spherre Account Description";
    let members: Array<ContractAddress> = array![owner, MEMBER_ONE(), MEMBER_TWO()];
    let threshold: u64 = 2;
    let account_address = spherre_dispatcher
        .deploy_account(owner, name, description, members, threshold);
    // Test newly deployed spherre contract
    assert(spherre_dispatcher.is_deployed_account(account_address), 'Account not deployed');
    let spherre_account_data_dispatcher = IAccountDataDispatcher {
        contract_address: account_address,
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

#[test]
#[should_panic(expected: 'Members must meet threshold')]
fn test_deploy_account_fail_with_invalid_threshold() {
    let spherre_contract = deploy_contract(OWNER());
    let spherre_dispatcher = ISpherreDispatcher { contract_address: spherre_contract };
    let owner = OWNER();
    // Set classhash
    let classhash: ClassHash = get_spherre_account_class_hash();
    cheat_set_account_class_hash(spherre_contract, classhash, owner);

    // Call the deploy account function

    let name: ByteArray = "Test Spherre Account";
    let description: ByteArray = "Test Spherre Account Description";
    let members: Array<ContractAddress> = array![owner, MEMBER_ONE(), MEMBER_TWO()];
    let threshold: u64 = 4; // invalid threshold. threshold is greater than number of members
    // should panic
    spherre_dispatcher.deploy_account(owner, name, description, members, threshold);
}
#[test]
#[should_panic(expected: 'Threshold must be > 0')]
fn test_deploy_account_fail_with_zero_threshold() {
    let spherre_contract = deploy_contract(OWNER());
    let spherre_dispatcher = ISpherreDispatcher { contract_address: spherre_contract };
    let owner = OWNER();
    // Set classhash
    let classhash: ClassHash = get_spherre_account_class_hash();
    cheat_set_account_class_hash(spherre_contract, classhash, owner);

    // Call the deploy account function

    let name: ByteArray = "Test Spherre Account";
    let description: ByteArray = "Test Spherre Account Description";
    let members: Array<ContractAddress> = array![owner, MEMBER_ONE(), MEMBER_TWO()];
    let threshold: u64 = 0; // zero threshold. threshold should not be zero
    // should panic
    spherre_dispatcher.deploy_account(owner, name, description, members, threshold);
}

#[test]
#[should_panic(expected: 'Members count must be > 0')]
fn test_deploy_account_fail_with_zero_members() {
    let spherre_contract = deploy_contract(OWNER());
    let spherre_dispatcher = ISpherreDispatcher { contract_address: spherre_contract };
    let owner = OWNER();
    // Set classhash
    let classhash: ClassHash = get_spherre_account_class_hash();
    cheat_set_account_class_hash(spherre_contract, classhash, owner);

    // Call the deploy account function

    let name: ByteArray = "Test Spherre Account";
    let description: ByteArray = "Test Spherre Account Description";
    let members: Array<ContractAddress> = array![]; // No members.
    let threshold: u64 = 1;
    // should panic
    spherre_dispatcher.deploy_account(owner, name, description, members, threshold);
}

#[test]
#[should_panic(expected: 'Owner should not be zero')]
fn test_deploy_account_fail_with_zero_owner() {
    let spherre_contract = deploy_contract(OWNER());
    let spherre_dispatcher = ISpherreDispatcher { contract_address: spherre_contract };
    let owner = OWNER();
    // Set classhash
    let classhash: ClassHash = get_spherre_account_class_hash();
    cheat_set_account_class_hash(spherre_contract, classhash, owner);

    // Call the deploy account function

    let name: ByteArray = "Test Spherre Account";
    let description: ByteArray = "Test Spherre Account Description";
    let members: Array<ContractAddress> = array![owner, MEMBER_ONE(), MEMBER_TWO()];
    let threshold: u64 = 2;
    let zero_owner: ContractAddress = 0.try_into().unwrap();
    // should panic
    spherre_dispatcher.deploy_account(zero_owner, name, description, members, threshold);
}

fn cheat_set_account_class_hash(
    contract_address: ContractAddress, new_hash: ClassHash, superadmin: ContractAddress,
) {
    start_cheat_caller_address(contract_address, superadmin);
    ISpherreDispatcher { contract_address }.update_account_class_hash(new_hash);
    stop_cheat_caller_address(contract_address);
}

// SuperAdmin Role Management
#[test]
fn test_owner_grant_superadmin_role_should_pass() { //Test events indirectly here
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);

    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();

    let mut spy = spy_events();

    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };
    start_cheat_caller_address(spherre_contract, owner);
    dispatcher.grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    let is_superadmin = dispatcher.has_superadmin_role(to_be_superadmin);
    assert(is_superadmin, 'Grant role failed');

    spy
        .assert_emitted(
            @array![
                (
                    spherre_contract,
                    AccessControlComponent::Event::RoleGranted(
                        AccessControlComponent::RoleGranted {
                            role: selector!("SUPERADMIN"), account: to_be_superadmin, sender: owner,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_non_owner_grant_superadmin_role_should_fail() {
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);
    let random_guy = contract_address_const::<'random_guy'>();

    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();

    let mut spy = spy_events();

    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };
    start_cheat_caller_address(spherre_contract, random_guy);
    dispatcher.grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    let is_superadmin = dispatcher.has_superadmin_role(to_be_superadmin);
    assert(!is_superadmin, 'Improper Access Control');

    spy
        .assert_not_emitted(
            @array![
                (
                    spherre_contract,
                    AccessControlComponent::Event::RoleGranted(
                        AccessControlComponent::RoleGranted {
                            role: selector!("SUPERADMIN"),
                            account: to_be_superadmin,
                            sender: random_guy,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_owner_revoke_superadmin_role_should_pass() { // also test event indirectly here
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);

    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();

    let mut spy = spy_events();

    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };
    start_cheat_caller_address(spherre_contract, owner);
    dispatcher.grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    let mut is_superadmin = dispatcher.has_superadmin_role(to_be_superadmin);
    assert(is_superadmin, 'Grant role failed');

    spy
        .assert_emitted(
            @array![
                (
                    spherre_contract,
                    AccessControlComponent::Event::RoleGranted(
                        AccessControlComponent::RoleGranted {
                            role: selector!("SUPERADMIN"), account: to_be_superadmin, sender: owner,
                        },
                    ),
                ),
            ],
        );

    start_cheat_caller_address(spherre_contract, owner);
    dispatcher.revoke_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    is_superadmin = dispatcher.has_superadmin_role(to_be_superadmin);
    assert(!is_superadmin, 'Revoke role failed');

    spy
        .assert_emitted(
            @array![
                (
                    spherre_contract,
                    AccessControlComponent::Event::RoleRevoked(
                        AccessControlComponent::RoleRevoked {
                            role: selector!("SUPERADMIN"), account: to_be_superadmin, sender: owner,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_non_owner_revoke_superadmin_role_should_fail() {
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);
    let random_guy = contract_address_const::<'random_guy'>();

    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();

    let mut spy = spy_events();

    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };
    start_cheat_caller_address(spherre_contract, owner);
    dispatcher.grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    let mut is_superadmin = dispatcher.has_superadmin_role(to_be_superadmin);
    assert(is_superadmin, 'Grant role failed');

    spy
        .assert_emitted(
            @array![
                (
                    spherre_contract,
                    AccessControlComponent::Event::RoleGranted(
                        AccessControlComponent::RoleGranted {
                            role: selector!("SUPERADMIN"), account: to_be_superadmin, sender: owner,
                        },
                    ),
                ),
            ],
        );

    start_cheat_caller_address(spherre_contract, random_guy);
    dispatcher.revoke_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    is_superadmin = dispatcher.has_superadmin_role(to_be_superadmin);
    assert(is_superadmin, 'Revoke role failed');

    spy
        .assert_not_emitted(
            @array![
                (
                    spherre_contract,
                    AccessControlComponent::Event::RoleRevoked(
                        AccessControlComponent::RoleRevoked {
                            role: selector!("SUPERADMIN"), account: to_be_superadmin, sender: owner,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_has_superadmin_role_with() {
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);

    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();
    let ordinary_guy = contract_address_const::<'ordinary_guy'>();

    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };
    start_cheat_caller_address(spherre_contract, owner);
    dispatcher.grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    let mut to_be_superadmin_is_superadmin = dispatcher.has_superadmin_role(to_be_superadmin);
    assert(to_be_superadmin_is_superadmin, 'Grant role failed');

    let ordinary_guy_is_superadmin = dispatcher.has_superadmin_role(ordinary_guy);
    assert(!ordinary_guy_is_superadmin, 'Mysterious role assumption');
}

// // Staff Role Management

#[test]
fn test_superadmin_grant_staff_role_should_pass() { //test event indirectly here
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);

    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();
    let to_be_staff = contract_address_const::<'to_be_staff'>();

    let mut spy = spy_events();

    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };
    start_cheat_caller_address(spherre_contract, owner);
    dispatcher.grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    let is_superadmin = dispatcher.has_superadmin_role(to_be_superadmin);
    assert(is_superadmin, 'Grant role failed');

    start_cheat_caller_address(spherre_contract, to_be_superadmin);
    dispatcher.grant_staff_role(to_be_staff);
    stop_cheat_caller_address(spherre_contract);

    let is_staff = dispatcher.has_staff_role(to_be_staff);
    assert(is_staff, 'Grant staff role failed');

    spy
        .assert_emitted(
            @array![
                (
                    spherre_contract,
                    AccessControlComponent::Event::RoleGranted(
                        AccessControlComponent::RoleGranted {
                            role: selector!("STAFF"),
                            account: to_be_staff,
                            sender: to_be_superadmin,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: 'Caller is not a superadmin')]
fn test_non_superadmin_grant_staff_role_should_fail() {
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);

    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();
    let to_be_staff = contract_address_const::<'to_be_staff'>();
    let random_guy = contract_address_const::<'random_guy'>();

    let mut spy = spy_events();

    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };
    start_cheat_caller_address(spherre_contract, owner);
    dispatcher.grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    let is_superadmin = dispatcher.has_superadmin_role(to_be_superadmin);
    assert(is_superadmin, 'Grant role failed');

    start_cheat_caller_address(spherre_contract, random_guy);
    dispatcher.grant_staff_role(to_be_staff);
    stop_cheat_caller_address(spherre_contract);

    let is_staff = dispatcher.has_staff_role(to_be_staff);
    assert(!is_staff, 'Mysterious role assumptions');

    spy
        .assert_not_emitted(
            @array![
                (
                    spherre_contract,
                    AccessControlComponent::Event::RoleGranted(
                        AccessControlComponent::RoleGranted {
                            role: selector!("STAFF"), account: to_be_staff, sender: random_guy,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_superadmin_revoke_staff_role_should_pass() {
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);

    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();
    let to_be_staff = contract_address_const::<'to_be_staff'>();

    let mut spy = spy_events();

    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };
    start_cheat_caller_address(spherre_contract, owner);
    dispatcher.grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    let mut is_superadmin = dispatcher.has_superadmin_role(to_be_superadmin);
    assert(is_superadmin, 'Grant role failed');

    spy
        .assert_emitted(
            @array![
                (
                    spherre_contract,
                    AccessControlComponent::Event::RoleGranted(
                        AccessControlComponent::RoleGranted {
                            role: selector!("SUPERADMIN"), account: to_be_superadmin, sender: owner,
                        },
                    ),
                ),
            ],
        );

    start_cheat_caller_address(spherre_contract, to_be_superadmin);
    dispatcher.grant_staff_role(to_be_staff);
    stop_cheat_caller_address(spherre_contract);

    let mut is_staff = dispatcher.has_staff_role(to_be_staff);
    assert(is_staff, 'Grant staff role failed');

    spy
        .assert_emitted(
            @array![
                (
                    spherre_contract,
                    AccessControlComponent::Event::RoleGranted(
                        AccessControlComponent::RoleGranted {
                            role: selector!("STAFF"),
                            account: to_be_staff,
                            sender: to_be_superadmin,
                        },
                    ),
                ),
            ],
        );

    start_cheat_caller_address(spherre_contract, to_be_superadmin);
    dispatcher.revoke_staff_role(to_be_staff);
    stop_cheat_caller_address(spherre_contract);

    let is_staff = dispatcher.has_staff_role(to_be_staff);
    assert(!is_staff, 'Revoke staff role failed');

    spy
        .assert_emitted(
            @array![
                (
                    spherre_contract,
                    AccessControlComponent::Event::RoleRevoked(
                        AccessControlComponent::RoleRevoked {
                            role: selector!("STAFF"),
                            account: to_be_staff,
                            sender: to_be_superadmin,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: 'Caller is not a superadmin')]
fn test_non_superadmin_revoke_staff_role_should_fail() {
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);

    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();
    let not_superadmin = contract_address_const::<'not_superadmin'>();

    let mut spy = spy_events();

    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };
    start_cheat_caller_address(spherre_contract, owner);
    dispatcher.grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    let mut is_superadmin = dispatcher.has_superadmin_role(to_be_superadmin);
    assert(is_superadmin, 'Grant role failed');

    spy
        .assert_emitted(
            @array![
                (
                    spherre_contract,
                    AccessControlComponent::Event::RoleGranted(
                        AccessControlComponent::RoleGranted {
                            role: selector!("SUPERADMIN"), account: to_be_superadmin, sender: owner,
                        },
                    ),
                ),
            ],
        );

    let to_be_staff = contract_address_const::<'to_be_staff'>();

    start_cheat_caller_address(spherre_contract, to_be_superadmin);
    dispatcher.grant_staff_role(to_be_staff);
    stop_cheat_caller_address(spherre_contract);

    let mut is_staff = dispatcher.has_staff_role(to_be_staff);
    assert(is_staff, 'Grant staff role failed');

    spy
        .assert_emitted(
            @array![
                (
                    spherre_contract,
                    AccessControlComponent::Event::RoleGranted(
                        AccessControlComponent::RoleGranted {
                            role: selector!("STAFF"),
                            account: to_be_staff,
                            sender: to_be_superadmin,
                        },
                    ),
                ),
            ],
        );

    start_cheat_caller_address(spherre_contract, not_superadmin);
    dispatcher.revoke_staff_role(to_be_staff);
    stop_cheat_caller_address(spherre_contract);

    is_staff = dispatcher.has_staff_role(to_be_staff);
    assert(is_staff, 'Mysterious role assumption');

    spy
        .assert_not_emitted(
            @array![
                (
                    spherre_contract,
                    AccessControlComponent::Event::RoleRevoked(
                        AccessControlComponent::RoleRevoked {
                            role: selector!("STAFF"), account: to_be_staff, sender: not_superadmin,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_has_staff_role() {
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);

    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();
    let to_be_staff = contract_address_const::<'to_be_staff'>();
    let ordinary_guy = contract_address_const::<'ordinary_guy'>();

    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };
    start_cheat_caller_address(spherre_contract, owner);
    dispatcher.grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    start_cheat_caller_address(spherre_contract, to_be_superadmin);
    dispatcher.grant_staff_role(to_be_staff);
    stop_cheat_caller_address(spherre_contract);

    let mut to_be_superadmin_is_superadmin = dispatcher.has_superadmin_role(to_be_superadmin);
    let mut to_be_superadmin_is_staff = dispatcher.has_staff_role(to_be_superadmin);
    assert(to_be_superadmin_is_superadmin, 'Grant role failed');
    assert(!to_be_superadmin_is_staff, 'Superadmin is staff');

    let mut to_be_staff_is_staff = dispatcher.has_staff_role(to_be_staff);
    let mut to_be_staff_is_superadmin = dispatcher.has_superadmin_role(to_be_staff);
    assert(to_be_staff_is_staff, 'Grant staff role failed');
    assert(!to_be_staff_is_superadmin, 'Staff is superadmin');

    let ordinary_guy_is_superadmin = dispatcher.has_superadmin_role(ordinary_guy);
    assert(!ordinary_guy_is_superadmin, 'Mysterious role assumption');
}

#[test]
fn test_update_account_class_hash_success_by_superadmin() {
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);

    let initial_hash: ClassHash = class_hash_const::<0x1>();
    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();

    start_cheat_caller_address(spherre_contract, owner);
    ISpherreDispatcher { contract_address: spherre_contract }
        .grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    cheat_set_account_class_hash(spherre_contract, initial_hash, to_be_superadmin);

    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };
    let old_hash = dispatcher.get_account_class_hash();
    assert(old_hash == initial_hash, 'Initial class hash mismatch');

    let NEW_CLASS_HASH: ClassHash = 0x2.try_into().unwrap();
    start_cheat_caller_address(spherre_contract, to_be_superadmin);
    dispatcher.update_account_class_hash(NEW_CLASS_HASH);
    stop_cheat_caller_address(spherre_contract);

    let updated_hash = dispatcher.get_account_class_hash();
    assert(updated_hash == NEW_CLASS_HASH, 'Caller is not a admin');
}
#[test]
#[should_panic(expected: 'Caller is not a superadmin')]
fn test_update_account_class_hash_rejected_for_non_superadmin() {
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);

    let NEW_CLASS_HASH: ClassHash = 0x2.try_into().unwrap();

    let random_guy = contract_address_const::<'random_guy'>();

    start_cheat_caller_address(spherre_contract, random_guy);
    ISpherreDispatcher { contract_address: spherre_contract }
        .update_account_class_hash(NEW_CLASS_HASH);
    stop_cheat_caller_address(spherre_contract);
}


#[test]
fn test_update_account_class_hash_emits_event() {
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);

    let initial_hash: ClassHash = class_hash_const::<0x1>();
    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();

    start_cheat_caller_address(spherre_contract, owner);
    ISpherreDispatcher { contract_address: spherre_contract }
        .grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    cheat_set_account_class_hash(spherre_contract, initial_hash, to_be_superadmin);

    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };
    let old_hash = dispatcher.get_account_class_hash();
    assert(old_hash == initial_hash, 'Initial class hash mismatch');

    let mut spy = spy_events();

    let new_hash: ClassHash = 0x2.try_into().unwrap();
    start_cheat_caller_address(spherre_contract, to_be_superadmin);
    dispatcher.update_account_class_hash(new_hash);
    stop_cheat_caller_address(spherre_contract);

    let expected_event = Spherre::Event::AccountClassHashUpdated(
        Spherre::AccountClassHashUpdated {
            old_class_hash: old_hash, new_class_hash: new_hash, caller: to_be_superadmin,
        },
    );

    spy.assert_emitted(@array![(spherre_contract, expected_event)]);
}

#[test]
#[should_panic(expected: 'Invalid class hash')]
fn test_update_account_class_hash_invalid_zero_hash_panics() {
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);

    let INVALID_HASH: ClassHash = class_hash_const::<0x0>();

    // Grant SUPERADMIN
    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();
    start_cheat_caller_address(spherre_contract, owner);
    ISpherreDispatcher { contract_address: spherre_contract }
        .grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    // Attempt to update to INVALID_HASH must panic
    start_cheat_caller_address(spherre_contract, to_be_superadmin);
    ISpherreDispatcher { contract_address: spherre_contract }
        .update_account_class_hash(INVALID_HASH);
    stop_cheat_caller_address(spherre_contract);
}
#[test]
#[should_panic(expected: 'Class hash unchanged')]
fn test_update_account_class_hash_same_hash_panics() {
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);

    let NEW_CLASS_HASH: ClassHash = 0x2.try_into().unwrap();

    // Grant SUPERADMIN
    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();
    start_cheat_caller_address(spherre_contract, owner);
    ISpherreDispatcher { contract_address: spherre_contract }
        .grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    start_cheat_caller_address(spherre_contract, to_be_superadmin);
    dispatcher.update_account_class_hash(NEW_CLASS_HASH);
    stop_cheat_caller_address(spherre_contract);

    start_cheat_caller_address(spherre_contract, to_be_superadmin);
    dispatcher.update_account_class_hash(NEW_CLASS_HASH);
    stop_cheat_caller_address(spherre_contract);
}

#[test]
fn test_update_fee_staff_success_emit_event() {
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);
    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();
    let to_be_staff = contract_address_const::<'to_be_staff'>();
    let account = contract_address_const::<'account'>();

    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    // Grant superadmin and staff roles
    start_cheat_caller_address(spherre_contract, owner);
    dispatcher.grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    start_cheat_caller_address(spherre_contract, to_be_superadmin);
    dispatcher.grant_staff_role(to_be_staff);
    stop_cheat_caller_address(spherre_contract);

    // Update fee as staff
    let mut spy = spy_events();
    let fee_type = FeesType::PROPOSAL_FEE;
    let fee_amount: u256 = 100;

    start_cheat_caller_address(spherre_contract, to_be_staff);
    dispatcher.update_fee(fee_type, fee_amount);
    stop_cheat_caller_address(spherre_contract);

    // Check getter
    let stored_fee = dispatcher.get_fee(fee_type, account);
    assert(stored_fee == fee_amount, 'Fee not updated correctly');
    assert(dispatcher.is_fee_enabled(fee_type), 'Fee should be enabled');

    // Check event
    let expected_event = Spherre::Event::FeeUpdated(
        Spherre::FeeUpdated { fee_type, amount: fee_amount, enabled: true, caller: to_be_staff },
    );
    spy.assert_emitted(@array![(spherre_contract, expected_event)]);
}

#[test]
fn test_update_fee_superadmin_success_emit_event() {
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);
    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();
    let account = contract_address_const::<'account'>();

    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    // Grant superadmin role
    start_cheat_caller_address(spherre_contract, owner);
    dispatcher.grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    // Update fee as superadmin
    let mut spy = spy_events();
    let fee_type = FeesType::PROPOSAL_FEE;
    let fee_amount: u256 = 100;

    start_cheat_caller_address(spherre_contract, to_be_superadmin);
    dispatcher.update_fee(fee_type, fee_amount);
    stop_cheat_caller_address(spherre_contract);

    // Check getter
    let stored_fee = dispatcher.get_fee(fee_type, account);
    assert(stored_fee == fee_amount, 'Fee not updated correctly');
    assert(dispatcher.is_fee_enabled(fee_type), 'Fee should be enabled');

    // Check event
    let expected_event = Spherre::Event::FeeUpdated(
        Spherre::FeeUpdated {
            fee_type, amount: fee_amount, enabled: true, caller: to_be_superadmin,
        },
    );
    spy.assert_emitted(@array![(spherre_contract, expected_event)]);
}

#[test]
#[should_panic(expected: 'Caller is not a staff')]
fn test_update_fee_by_non_staff_should_fail() {
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);
    let random_guy = contract_address_const::<'random_guy'>();

    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    let fee_type = FeesType::PROPOSAL_FEE;
    let fee_amount: u256 = 100;

    start_cheat_caller_address(spherre_contract, random_guy);
    dispatcher.update_fee(fee_type, fee_amount);
    stop_cheat_caller_address(spherre_contract);
}

#[test]
fn test_update_fee_token_superadmin_success_emit_event() {
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);
    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();
    let new_token = contract_address_const::<'fee_token'>();

    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    // Grant superadmin
    start_cheat_caller_address(spherre_contract, owner);
    dispatcher.grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    // Set initial token
    let initial_token: ContractAddress = 0x123.try_into().unwrap();
    start_cheat_caller_address(spherre_contract, to_be_superadmin);
    dispatcher.update_fee_token(initial_token);
    stop_cheat_caller_address(spherre_contract);

    // Update token
    let mut spy = spy_events();
    start_cheat_caller_address(spherre_contract, to_be_superadmin);
    dispatcher.update_fee_token(new_token);
    stop_cheat_caller_address(spherre_contract);

    // Check getter
    let stored_token = dispatcher.get_fee_token();
    assert(stored_token == new_token, 'Fee token not updated correctly');

    // Check event
    let expected_event = Spherre::Event::FeeTokenUpdated(
        Spherre::FeeTokenUpdated { old_token: initial_token, new_token, caller: to_be_superadmin },
    );
    spy.assert_emitted(@array![(spherre_contract, expected_event)]);
}

#[test]
#[should_panic(expected: 'Caller is not a superadmin')]
fn test_update_fee_token_staff_fails() {
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);
    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();
    let to_be_staff = contract_address_const::<'to_be_staff'>();
    let new_token = contract_address_const::<'fee_token'>();

    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    // Grant superadmin and staff roles
    start_cheat_caller_address(spherre_contract, owner);
    dispatcher.grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    start_cheat_caller_address(spherre_contract, to_be_superadmin);
    dispatcher.grant_staff_role(to_be_staff);
    stop_cheat_caller_address(spherre_contract);

    // Try to update fee token as staff
    start_cheat_caller_address(spherre_contract, to_be_staff);
    dispatcher.update_fee_token(new_token);
    stop_cheat_caller_address(spherre_contract);
}

#[test]
#[should_panic(expected: 'Caller is not a superadmin')]
fn test_update_fee_token_non_superadmin_should_fail() {
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);
    let random_guy = contract_address_const::<'random_guy'>();
    let new_token = contract_address_const::<'fee_token'>();

    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    start_cheat_caller_address(spherre_contract, random_guy);
    dispatcher.update_fee_token(new_token);
    stop_cheat_caller_address(spherre_contract);
}

#[test]
#[should_panic(expected: 'Token address is zero')]
fn test_update_fee_token_with_zero_address_should_fail() {
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);
    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();

    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    // Grant superadmin
    start_cheat_caller_address(spherre_contract, owner);
    dispatcher.grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    // Try to set zero address
    let zero_address: ContractAddress = contract_address_const::<0x0>();
    start_cheat_caller_address(spherre_contract, to_be_superadmin);
    dispatcher.update_fee_token(zero_address);
    stop_cheat_caller_address(spherre_contract);
}

#[test]
fn test_get_not_enabled_fee_returns_zero() {
    let owner = contract_address_const::<'owner'>();
    let spherre_contract = deploy_contract(owner);
    let account = contract_address_const::<'account'>();

    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    let fee_type = FeesType::EXECUTION_FEE;
    let fee: u256 = dispatcher.get_fee(fee_type, account);
    assert(fee == 0_u256, 'Fee should be zero');
    assert(!dispatcher.is_fee_enabled(fee_type), 'Fee should not be enabled');
}

#[test]
fn test_whitelist_account_success() {
    let owner = OWNER();
    let spherre_contract = deploy_contract(owner);
    let spherre_dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();
    let to_be_staff = contract_address_const::<'to_be_staff'>();

    // Set classhash
    let classhash: ClassHash = get_spherre_account_class_hash();
    cheat_set_account_class_hash(spherre_contract, classhash, owner);

    // Grant superadmin role
    start_cheat_caller_address(spherre_contract, owner);
    spherre_dispatcher.grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    // Grant staff role
    start_cheat_caller_address(spherre_contract, to_be_superadmin);
    spherre_dispatcher.grant_staff_role(to_be_staff);
    stop_cheat_caller_address(spherre_contract);

    // Deploy an account
    let name: ByteArray = "Test Spherre Account";
    let description: ByteArray = "Test Spherre Account Description";
    let members: Array<ContractAddress> = array![owner, MEMBER_ONE(), MEMBER_TWO()];
    let threshold: u64 = 2;
    let account_address = spherre_dispatcher
        .deploy_account(owner, name, description, members, threshold);

    // Whitelist the account
    let mut spy = spy_events();
    start_cheat_caller_address(spherre_contract, to_be_staff);
    spherre_dispatcher.whitelist_account(account_address);
    stop_cheat_caller_address(spherre_contract);

    // Check if the account is whitelisted
    let is_whitelisted = spherre_dispatcher.is_whitelisted_account(account_address);
    assert(is_whitelisted, 'Account not whitelisted');

    // Check AccountWhitelisted event
    let expected_event = Spherre::Event::AccountWhitelisted(
        Spherre::AccountWhitelisted { account: account_address, timestamp: 0, admin: to_be_staff, }
    );
    spy.assert_emitted(@array![(spherre_contract, expected_event)]);
}

#[test]
#[should_panic(expected: 'Account should not be zero')]
fn test_whitelist_account_zero_address_should_fail() {
    let owner = OWNER();
    let spherre_contract = deploy_contract(owner);
    let spherre_dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    // Try to whitelist zero address
    let zero_address: ContractAddress = 0.try_into().unwrap();
    spherre_dispatcher.whitelist_account(zero_address);
}


#[test]
#[should_panic(expected: 'Caller is not a staff')]
fn test_whitelist_account_non_staff_should_fail() {
    let owner = OWNER();
    let spherre_contract = deploy_contract(owner);
    let spherre_dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    // Set classhash
    let classhash: ClassHash = get_spherre_account_class_hash();
    cheat_set_account_class_hash(spherre_contract, classhash, owner);

    // Deploy an account
    let name: ByteArray = "Test Spherre Account";
    let description: ByteArray = "Test Spherre Account Description";
    let members: Array<ContractAddress> = array![owner, MEMBER_ONE(), MEMBER_TWO()];
    let threshold: u64 = 2;
    let account_address = spherre_dispatcher
        .deploy_account(owner, name, description, members, threshold);

    // Try to whitelist an account as non-staff
    let non_staff = contract_address_const::<'non_staff'>();
    start_cheat_caller_address(spherre_contract, non_staff);
    spherre_dispatcher.whitelist_account(account_address);
    stop_cheat_caller_address(spherre_contract);
}

#[test]
#[should_panic(expected: 'Account is not deployed')]
fn test_whitelist_account_non_deployed_should_fail() {
    let owner = OWNER();
    let spherre_contract = deploy_contract(owner);
    let spherre_dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();
    let to_be_staff = contract_address_const::<'to_be_staff'>();

    // Set classhash
    let classhash: ClassHash = get_spherre_account_class_hash();
    cheat_set_account_class_hash(spherre_contract, classhash, owner);

    // Grant superadmin role
    start_cheat_caller_address(spherre_contract, owner);
    spherre_dispatcher.grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    // Grant staff role
    start_cheat_caller_address(spherre_contract, to_be_superadmin);
    spherre_dispatcher.grant_staff_role(to_be_staff);
    stop_cheat_caller_address(spherre_contract);

    // Try to whitelist an account that is not deployed
    let not_deployed_account = contract_address_const::<'not_deployed_account'>();
    start_cheat_caller_address(spherre_contract, to_be_staff);
    spherre_dispatcher.whitelist_account(not_deployed_account);
    stop_cheat_caller_address(spherre_contract);
}

#[test]
#[should_panic(expected: 'Account already whitelisted')]
fn test_whitelist_account_already_whitelisted_should_fail() {
    let owner = OWNER();
    let spherre_contract = deploy_contract(owner);
    let spherre_dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();
    let to_be_staff = contract_address_const::<'to_be_staff'>();

    // Set classhash
    let classhash: ClassHash = get_spherre_account_class_hash();
    cheat_set_account_class_hash(spherre_contract, classhash, owner);

    // Grant superadmin role
    start_cheat_caller_address(spherre_contract, owner);
    spherre_dispatcher.grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    // Grant staff role
    start_cheat_caller_address(spherre_contract, to_be_superadmin);
    spherre_dispatcher.grant_staff_role(to_be_staff);
    stop_cheat_caller_address(spherre_contract);

    // Deploy an account
    let name: ByteArray = "Test Spherre Account";
    let description: ByteArray = "Test Spherre Account Description";
    let members: Array<ContractAddress> = array![owner, MEMBER_ONE(), MEMBER_TWO()];
    let threshold: u64 = 2;
    let account_address = spherre_dispatcher
        .deploy_account(owner, name, description, members, threshold);

    // Whitelist the account
    start_cheat_caller_address(spherre_contract, to_be_staff);
    spherre_dispatcher.whitelist_account(account_address);
    stop_cheat_caller_address(spherre_contract);

    // Try to whitelist again
    start_cheat_caller_address(spherre_contract, to_be_staff);
    spherre_dispatcher.whitelist_account(account_address);
    stop_cheat_caller_address(spherre_contract);
}

#[test]
fn test_whitelist_user_success() {
    let owner = OWNER();
    let spherre_contract = deploy_contract(owner);
    let spherre_dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();
    let to_be_staff = contract_address_const::<'to_be_staff'>();
    let user = contract_address_const::<'user'>();

    // Set classhash
    let classhash: ClassHash = get_spherre_account_class_hash();
    cheat_set_account_class_hash(spherre_contract, classhash, owner);

    // Grant superadmin role
    start_cheat_caller_address(spherre_contract, owner);
    spherre_dispatcher.grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    // Grant staff role
    start_cheat_caller_address(spherre_contract, to_be_superadmin);
    spherre_dispatcher.grant_staff_role(to_be_staff);
    stop_cheat_caller_address(spherre_contract);

    // Whitelist the user
    let mut spy = spy_events();
    start_cheat_caller_address(spherre_contract, to_be_staff);
    spherre_dispatcher.whitelist_user(user);
    stop_cheat_caller_address(spherre_contract);

    // Check if the user is whitelisted
    let is_whitelisted = spherre_dispatcher.is_whitelisted_user(user);
    assert(is_whitelisted, 'User not whitelisted');

    // Check UserWhitelisted event
    let expected_event = Spherre::Event::UserWhitelisted(
        Spherre::UserWhitelisted { user, timestamp: 0, admin: to_be_staff, }
    );
    spy.assert_emitted(@array![(spherre_contract, expected_event)]);
}

#[test]
#[should_panic(expected: 'User address is zero')]
fn test_whitelist_user_zero_address_should_fail() {
    let owner = OWNER();
    let spherre_contract = deploy_contract(owner);
    let spherre_dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    // Try to whitelist zero address
    let zero_address: ContractAddress = 0.try_into().unwrap();
    spherre_dispatcher.whitelist_user(zero_address);
}

#[test]
#[should_panic(expected: 'Caller is not a staff')]
fn test_whitelist_user_non_staff_should_fail() {
    let owner = OWNER();
    let spherre_contract = deploy_contract(owner);
    let spherre_dispatcher = ISpherreDispatcher { contract_address: spherre_contract };
    let user = contract_address_const::<'user'>();

    // Try to whitelist a user as non-staff
    let non_staff = contract_address_const::<'non_staff'>();
    start_cheat_caller_address(spherre_contract, non_staff);
    spherre_dispatcher.whitelist_user(user);
    stop_cheat_caller_address(spherre_contract);
}

#[test]
#[should_panic(expected: 'User already whitelisted')]
fn test_whitelist_user_already_whitelisted_should_fail() {
    let owner = OWNER();
    let spherre_contract = deploy_contract(owner);
    let spherre_dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();
    let to_be_staff = contract_address_const::<'to_be_staff'>();
    let user = contract_address_const::<'user'>();

    // Set classhash
    let classhash: ClassHash = get_spherre_account_class_hash();
    cheat_set_account_class_hash(spherre_contract, classhash, owner);

    // Grant superadmin role
    start_cheat_caller_address(spherre_contract, owner);
    spherre_dispatcher.grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    // Grant staff role
    start_cheat_caller_address(spherre_contract, to_be_superadmin);
    spherre_dispatcher.grant_staff_role(to_be_staff);
    stop_cheat_caller_address(spherre_contract);

    // Whitelist the user
    start_cheat_caller_address(spherre_contract, to_be_staff);
    spherre_dispatcher.whitelist_user(user);
    stop_cheat_caller_address(spherre_contract);

    // Try to whitelist again
    start_cheat_caller_address(spherre_contract, to_be_staff);
    spherre_dispatcher.whitelist_user(user);
    stop_cheat_caller_address(spherre_contract);
}

#[test]
fn test_remove_account_from_whitelist_success() {
    let owner = OWNER();
    let spherre_contract = deploy_contract(owner);
    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    let superadmin = contract_address_const::<'superadmin'>();
    let staff = contract_address_const::<'staff'>();

    // Set classhash
    let classhash: ClassHash = get_spherre_account_class_hash();
    cheat_set_account_class_hash(spherre_contract, classhash, owner);

    // Grant roles
    start_cheat_caller_address(spherre_contract, owner);
    dispatcher.grant_superadmin_role(superadmin);
    stop_cheat_caller_address(spherre_contract);

    start_cheat_caller_address(spherre_contract, superadmin);
    dispatcher.grant_staff_role(staff);
    stop_cheat_caller_address(spherre_contract);

    // Deploy an account
    let name: ByteArray = "Test Spherre Account";
    let description: ByteArray = "Test Spherre Account Description";
    let members: Array<ContractAddress> = array![owner, MEMBER_ONE(), MEMBER_TWO()];
    let threshold: u64 = 2;
    let account_address = dispatcher.deploy_account(owner, name, description, members, threshold);

    start_cheat_caller_address(spherre_contract, staff);
    dispatcher.whitelist_account(account_address);
    stop_cheat_caller_address(spherre_contract);

    // Verify count before removal
    let before_count = dispatcher.get_whitelisted_accounts_count();
    assert(before_count == 1_u256, 'Wrong count before');

    // Remove account
    let mut spy = spy_events();
    start_cheat_caller_address(spherre_contract, staff);
    dispatcher.remove_account_from_whitelist(account_address);
    stop_cheat_caller_address(spherre_contract);

    let after_count = dispatcher.get_whitelisted_accounts_count();
    assert(after_count == 0_u256, 'Wrong count after');
    let is_whitelisted = dispatcher.is_whitelisted_account(account_address);
    assert(!is_whitelisted, 'Still whitelisted');

    // Check event
    let expected_event = Spherre::Event::AccountRemovedFromWhitelist(
        Spherre::AccountRemovedFromWhitelist {
            account: account_address, timestamp: 0, admin: staff
        }
    );
    spy.assert_emitted(@array![(spherre_contract, expected_event)]);
}

#[test]
#[should_panic(expected: 'Account should not be zero')]
fn test_remove_account_from_whitelist_zero_address_should_fail() {
    let owner = OWNER();
    let spherre_contract = deploy_contract(owner);
    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    let superadmin = contract_address_const::<'superadmin'>();
    let staff = contract_address_const::<'staff'>();

    // Grant roles
    start_cheat_caller_address(spherre_contract, owner);
    dispatcher.grant_superadmin_role(superadmin);
    stop_cheat_caller_address(spherre_contract);
    start_cheat_caller_address(spherre_contract, superadmin);
    dispatcher.grant_staff_role(staff);
    stop_cheat_caller_address(spherre_contract);

    // Try to remove zero address
    let zero_address: ContractAddress = 0.try_into().unwrap();
    start_cheat_caller_address(spherre_contract, staff);
    dispatcher.remove_account_from_whitelist(zero_address);
    stop_cheat_caller_address(spherre_contract);
}

#[test]
#[should_panic(expected: 'Caller is not a staff')]
fn test_remove_account_from_whitelist_non_staff_should_fail() {
    let owner = OWNER();
    let spherre_contract = deploy_contract(owner);
    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    // Set classhash first
    let classhash: ClassHash = get_spherre_account_class_hash();
    cheat_set_account_class_hash(spherre_contract, classhash, owner);

    // Deploy account
    let name: ByteArray = "Test Spherre Account";
    let description: ByteArray = "Test Spherre Account Description";
    let members: Array<ContractAddress> = array![owner, MEMBER_ONE(), MEMBER_TWO()];
    let threshold: u64 = 2;
    let account_address = dispatcher.deploy_account(owner, name, description, members, threshold);

    // Try remove without staff role
    let non_staff = contract_address_const::<'non_staff'>();
    start_cheat_caller_address(spherre_contract, non_staff);
    dispatcher.remove_account_from_whitelist(account_address);
    stop_cheat_caller_address(spherre_contract);
}

#[test]
#[should_panic(expected: 'Account not whitelisted')]
fn test_remove_account_from_whitelist_not_whitelisted_should_fail() {
    let owner = OWNER();
    let spherre_contract = deploy_contract(owner);
    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    let superadmin = contract_address_const::<'superadmin'>();
    let staff = contract_address_const::<'staff'>();

    // Grant roles
    start_cheat_caller_address(spherre_contract, owner);
    dispatcher.grant_superadmin_role(superadmin);
    stop_cheat_caller_address(spherre_contract);
    start_cheat_caller_address(spherre_contract, superadmin);
    dispatcher.grant_staff_role(staff);
    stop_cheat_caller_address(spherre_contract);

    // Non-whitelisted account address
    let some_account = contract_address_const::<'some_account'>();
    start_cheat_caller_address(spherre_contract, staff);
    dispatcher.remove_account_from_whitelist(some_account);
    stop_cheat_caller_address(spherre_contract);
}

#[test]
fn test_remove_user_from_whitelist_success() {
    let owner = OWNER();
    let spherre_contract = deploy_contract(owner);
    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    let superadmin = contract_address_const::<'superadmin'>();
    let staff = contract_address_const::<'staff'>();
    let user = contract_address_const::<'user_to_remove'>();

    // Grant roles
    start_cheat_caller_address(spherre_contract, owner);
    dispatcher.grant_superadmin_role(superadmin);
    stop_cheat_caller_address(spherre_contract);
    start_cheat_caller_address(spherre_contract, superadmin);
    dispatcher.grant_staff_role(staff);
    stop_cheat_caller_address(spherre_contract);

    // Whitelist user
    start_cheat_caller_address(spherre_contract, staff);
    dispatcher.whitelist_user(user);
    stop_cheat_caller_address(spherre_contract);

    // Verify count before removal
    let before_count = dispatcher.get_whitelisted_users_count();
    assert(before_count == 1_u256, 'Wrong user count before');

    // Remove user
    let mut spy = spy_events();
    start_cheat_caller_address(spherre_contract, staff);
    dispatcher.remove_user_from_whitelist(user);
    stop_cheat_caller_address(spherre_contract);

    let after_count = dispatcher.get_whitelisted_users_count();
    assert(after_count == 0_u256, 'Wrong user count after');
    let is_whitelisted = dispatcher.is_whitelisted_user(user);
    assert(!is_whitelisted, 'User still whitelisted');

    // Check event
    let expected_event = Spherre::Event::UserRemovedFromWhitelist(
        Spherre::UserRemovedFromWhitelist { user, timestamp: 0, admin: staff }
    );
    spy.assert_emitted(@array![(spherre_contract, expected_event)]);
}

#[test]
#[should_panic(expected: 'User address is zero')]
fn test_remove_user_from_whitelist_zero_address_should_fail() {
    let owner = OWNER();
    let spherre_contract = deploy_contract(owner);
    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    let superadmin = contract_address_const::<'superadmin'>();
    let staff = contract_address_const::<'staff'>();

    // Grant roles
    start_cheat_caller_address(spherre_contract, owner);
    dispatcher.grant_superadmin_role(superadmin);
    stop_cheat_caller_address(spherre_contract);
    start_cheat_caller_address(spherre_contract, superadmin);
    dispatcher.grant_staff_role(staff);
    stop_cheat_caller_address(spherre_contract);

    // Try to remove zero address
    let zero_address: ContractAddress = 0.try_into().unwrap();
    start_cheat_caller_address(spherre_contract, staff);
    dispatcher.remove_user_from_whitelist(zero_address);
    stop_cheat_caller_address(spherre_contract);
}

#[test]
#[should_panic(expected: 'Caller is not a staff')]
fn test_remove_user_from_whitelist_non_staff_should_fail() {
    let owner = OWNER();
    let spherre_contract = deploy_contract(owner);
    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    let user = contract_address_const::<'user_to_remove'>();
    // Try remove without staff role
    let non_staff = contract_address_const::<'non_staff'>();
    start_cheat_caller_address(spherre_contract, non_staff);
    dispatcher.remove_user_from_whitelist(user);
    stop_cheat_caller_address(spherre_contract);
}

#[test]
#[should_panic(expected: 'User not whitelisted')]
fn test_remove_user_from_whitelist_not_whitelisted_should_fail() {
    let owner = OWNER();
    let spherre_contract = deploy_contract(owner);
    let dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    let superadmin = contract_address_const::<'superadmin'>();
    let staff = contract_address_const::<'staff'>();
    let user = contract_address_const::<'user_to_remove'>();

    // Grant roles
    start_cheat_caller_address(spherre_contract, owner);
    dispatcher.grant_superadmin_role(superadmin);
    stop_cheat_caller_address(spherre_contract);
    start_cheat_caller_address(spherre_contract, superadmin);
    dispatcher.grant_staff_role(staff);
    stop_cheat_caller_address(spherre_contract);

    // Attempt removal without prior whitelist
    start_cheat_caller_address(spherre_contract, staff);
    dispatcher.remove_user_from_whitelist(user);
    stop_cheat_caller_address(spherre_contract);
}

#[test]
fn test_get_whitelist_time_with_timestamp() {
    let owner = OWNER();
    let spherre_contract = deploy_contract(owner);
    let spherre_dispatcher = ISpherreDispatcher { contract_address: spherre_contract };

    let to_be_superadmin = contract_address_const::<'to_be_superadmin'>();
    let to_be_staff = contract_address_const::<'to_be_staff'>();

    // Set classhash
    let classhash: ClassHash = get_spherre_account_class_hash();
    cheat_set_account_class_hash(spherre_contract, classhash, owner);

    // Grant superadmin role
    start_cheat_caller_address(spherre_contract, owner);
    spherre_dispatcher.grant_superadmin_role(to_be_superadmin);
    stop_cheat_caller_address(spherre_contract);

    // Grant staff role
    start_cheat_caller_address(spherre_contract, to_be_superadmin);
    spherre_dispatcher.grant_staff_role(to_be_staff);
    stop_cheat_caller_address(spherre_contract);

    // Set initial timestamp and whitelist user
    let initial_timestamp: u64 = 1000;
    start_cheat_block_timestamp(spherre_contract, initial_timestamp);

    let user = contract_address_const::<'wt_user'>();
    start_cheat_caller_address(spherre_contract, to_be_staff);
    spherre_dispatcher.whitelist_user(user);
    stop_cheat_caller_address(spherre_contract);

    // Check timestamp for user
    let ts_user = spherre_dispatcher.get_whitelist_time(user, false);
    assert(ts_user == initial_timestamp, 'Wrong user timestamp');

    // Set new timestamp and whitelist account
    let new_timestamp: u64 = 2000;
    start_cheat_block_timestamp(spherre_contract, new_timestamp);

    // Deploy an account
    let name: ByteArray = "Test Spherre Account";
    let description: ByteArray = "Test Spherre Account Description";
    let members: Array<ContractAddress> = array![owner, MEMBER_ONE(), MEMBER_TWO()];
    let threshold: u64 = 2;
    let account_address = spherre_dispatcher
        .deploy_account(owner, name, description, members, threshold);

    start_cheat_caller_address(spherre_contract, to_be_staff);
    spherre_dispatcher.whitelist_account(account_address);
    stop_cheat_caller_address(spherre_contract);

    // Check timestamp for account
    let ts_account = spherre_dispatcher.get_whitelist_time(account_address, true);
    assert(ts_account == new_timestamp, 'Wrong account timestamp');

    stop_cheat_block_timestamp(spherre_contract);
}
