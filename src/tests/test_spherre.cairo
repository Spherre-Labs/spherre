use crate::account::{SpherreAccount};
use crate::interfaces::iaccount::{IAccountDispatcher, IAccountDispatcherTrait};
use crate::interfaces::iaccount_data::{IAccountDataDispatcher, IAccountDataDispatcherTrait};
use crate::interfaces::ispherre::{ISpherre, ISpherreDispatcher, ISpherreDispatcherTrait};
use crate::spherre::Spherre::Event::{AccountClassHashUpdated};
use crate::spherre::Spherre::{SpherreImpl};
use crate::spherre::Spherre;
use openzeppelin::access::accesscontrol::{DEFAULT_ADMIN_ROLE, AccessControlComponent};
use snforge_std::{
    start_cheat_caller_address, stop_cheat_caller_address, declare, ContractClassTrait, spy_events,
    EventSpyAssertionsTrait, DeclareResultTrait, get_class_hash
};
use spherre::types::SpherreAdminRoles;
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

// TODO: Wait for classhash setter function in order to conplete the test case

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
                            role: selector!("SUPERADMIN"), account: to_be_superadmin, sender: owner
                        },
                    )
                )
            ]
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
                            sender: random_guy
                        },
                    )
                )
            ]
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
                            role: selector!("SUPERADMIN"), account: to_be_superadmin, sender: owner
                        },
                    )
                )
            ]
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
                            role: selector!("SUPERADMIN"), account: to_be_superadmin, sender: owner
                        },
                    )
                )
            ]
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
                            role: selector!("SUPERADMIN"), account: to_be_superadmin, sender: owner
                        },
                    )
                )
            ]
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
                            role: selector!("SUPERADMIN"), account: to_be_superadmin, sender: owner
                        },
                    )
                )
            ]
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
                            role: selector!("STAFF"), account: to_be_staff, sender: to_be_superadmin
                        },
                    )
                )
            ]
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
                            role: selector!("STAFF"), account: to_be_staff, sender: random_guy
                        },
                    )
                )
            ]
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
                            role: selector!("SUPERADMIN"), account: to_be_superadmin, sender: owner
                        },
                    )
                )
            ]
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
                            role: selector!("STAFF"), account: to_be_staff, sender: to_be_superadmin
                        },
                    )
                )
            ]
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
                            role: selector!("STAFF"), account: to_be_staff, sender: to_be_superadmin
                        },
                    )
                )
            ]
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
                            role: selector!("SUPERADMIN"), account: to_be_superadmin, sender: owner
                        },
                    )
                )
            ]
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
                            role: selector!("STAFF"), account: to_be_staff, sender: to_be_superadmin
                        },
                    )
                )
            ]
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
                            role: selector!("STAFF"), account: to_be_staff, sender: not_superadmin
                        },
                    )
                )
            ]
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
        }
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

