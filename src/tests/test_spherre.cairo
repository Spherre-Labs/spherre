use crate::interfaces::ispherre::{ISpherre, ISpherreDispatcher, ISpherreDispatcherTrait};
use crate::spherre::Spherre::{SpherreImpl};
use crate::spherre::Spherre;
use openzeppelin::access::accesscontrol::{DEFAULT_ADMIN_ROLE, AccessControlComponent};
use snforge_std::{
    start_cheat_caller_address, stop_cheat_caller_address, declare, ContractClassTrait, spy_events,
    EventSpyAssertionsTrait, DeclareResultTrait
};
use spherre::types::SpherreAdminRoles;
use starknet::{ContractAddress, contract_address_const};

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
                            role: selector!("STAFF"), account: to_be_staff, sender: to_be_superadmin
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
                            role: selector!("STAFF"), account: to_be_staff, sender: to_be_superadmin
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
