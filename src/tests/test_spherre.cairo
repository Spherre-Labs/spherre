use debug::PrintTrait;
use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventAssertions, EventSpy, SpyOn, declare, spy_events,
    start_cheat_caller_address, start_prank, stop_cheat_caller_address, stop_prank,
};
use starknet::{ContractAddress, contract_address_const};
use crate::interfaces::ispherre::{ISpherre, ISpherreDispatcher, ISpherreDispatcherTrait};
use crate::spherre::Spherre;
use crate::spherre::Spherre::SpherreImpl;
use crate::types::SpherreAdminRoles;

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

// Define test addresses
fn owner() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

fn super_admin() -> ContractAddress {
    contract_address_const::<'SUPER_ADMIN'>()
}

fn staff() -> ContractAddress {
    contract_address_const::<'STAFF'>()
}

fn non_admin() -> ContractAddress {
    contract_address_const::<'NON_ADMIN'>()
}

#[test]
fn test_constructor() {
    // Deploy contract with owner
    let contract_address = deploy_contract(owner());
    let dispatcher = ISpherreDispatcher { contract_address };

    // Verify owner has superadmin role
    assert(dispatcher.has_superadmin_role(owner()), 'Owner should be SuperAdmin');
}

// ---------------------- SuperAdmin Role Management Tests ----------------------

#[test]
fn test_grant_superadmin_role_by_owner() {
    // Deploy contract with owner
    let contract_address = deploy_contract(owner());
    let dispatcher = ISpherreDispatcher { contract_address };

    // Set up event spy
    let mut spy = spy_events(SpyOn::One(contract_address));

    // Grant superadmin role to another address by owner
    start_prank(contract_address, owner());
    dispatcher.grant_superadmin_role(super_admin());
    stop_prank(contract_address);

    // Verify role was granted
    assert(dispatcher.has_superadmin_role(super_admin()), 'SuperAdmin role not granted');

    // Verify event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Spherre::Event::AccessControlEvent(
                        openzeppelin::access::accesscontrol::AccessControlComponent::Event::RoleGranted(
                            openzeppelin::access::accesscontrol::AccessControlComponent::RoleGranted {
                                role: SpherreAdminRoles::SUPERADMIN,
                                account: super_admin(),
                                sender: owner(),
                            },
                        ),
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_grant_superadmin_role_by_non_owner() {
    // Deploy contract with owner
    let contract_address = deploy_contract(owner());
    let dispatcher = ISpherreDispatcher { contract_address };

    // Try to grant superadmin role by non-owner
    start_prank(contract_address, non_admin());
    dispatcher.grant_superadmin_role(super_admin());
    stop_prank(contract_address);
}

#[test]
fn test_revoke_superadmin_role_by_owner() {
    // Deploy contract with owner
    let contract_address = deploy_contract(owner());
    let dispatcher = ISpherreDispatcher { contract_address };

    // First grant superadmin role
    start_prank(contract_address, owner());
    dispatcher.grant_superadmin_role(super_admin());

    // Set up event spy for revocation
    let mut spy = spy_events(SpyOn::One(contract_address));

    // Revoke superadmin role
    dispatcher.revoke_superadmin_role(super_admin());
    stop_prank(contract_address);

    // Verify role was revoked
    assert(!dispatcher.has_superadmin_role(super_admin()), 'SuperAdmin role not revoked');

    // Verify event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Spherre::Event::AccessControlEvent(
                        openzeppelin::access::accesscontrol::AccessControlComponent::Event::RoleRevoked(
                            openzeppelin::access::accesscontrol::AccessControlComponent::RoleRevoked {
                                role: SpherreAdminRoles::SUPERADMIN,
                                account: super_admin(),
                                sender: owner(),
                            },
                        ),
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_revoke_superadmin_role_by_non_owner() {
    // Deploy contract with owner
    let contract_address = deploy_contract(owner());
    let dispatcher = ISpherreDispatcher { contract_address };

    // First grant superadmin role
    start_prank(contract_address, owner());
    dispatcher.grant_superadmin_role(super_admin());
    stop_prank(contract_address);

    // Try to revoke superadmin role by non-owner
    start_prank(contract_address, non_admin());
    dispatcher.revoke_superadmin_role(super_admin());
    stop_prank(contract_address);
}

#[test]
fn test_has_superadmin_role() {
    // Deploy contract with owner
    let contract_address = deploy_contract(owner());
    let dispatcher = ISpherreDispatcher { contract_address };

    // Owner should have superadmin role by default
    assert(dispatcher.has_superadmin_role(owner()), 'Owner should have SuperAdmin role');

    // Grant superadmin role to another address
    start_prank(contract_address, owner());
    dispatcher.grant_superadmin_role(super_admin());
    stop_prank(contract_address);

    // Verify role checks
    assert(dispatcher.has_superadmin_role(super_admin()), 'SuperAdmin should have role');
    assert(!dispatcher.has_superadmin_role(non_admin()), 'Non-admin should not have role');
}

// ---------------------- Staff Role Management Tests ----------------------

#[test]
fn test_grant_staff_role_by_superadmin() {
    // Deploy contract with owner
    let contract_address = deploy_contract(owner());
    let dispatcher = ISpherreDispatcher { contract_address };

    // Grant superadmin role to another address
    start_prank(contract_address, owner());
    dispatcher.grant_superadmin_role(super_admin());
    stop_prank(contract_address);

    // Set up event spy
    let mut spy = spy_events(SpyOn::One(contract_address));

    // Grant staff role by superadmin
    start_prank(contract_address, super_admin());
    dispatcher.grant_staff_role(staff());
    stop_prank(contract_address);

    // Verify role was granted
    assert(dispatcher.has_staff_role(staff()), 'Staff role not granted');

    // Verify event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Spherre::Event::AccessControlEvent(
                        openzeppelin::access::accesscontrol::AccessControlComponent::Event::RoleGranted(
                            openzeppelin::access::accesscontrol::AccessControlComponent::RoleGranted {
                                role: SpherreAdminRoles::STAFF,
                                account: staff(),
                                sender: super_admin(),
                            },
                        ),
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: ('ERR_NOT_A_SUPERADMIN',))]
fn test_grant_staff_role_by_non_superadmin() {
    // Deploy contract with owner
    let contract_address = deploy_contract(owner());
    let dispatcher = ISpherreDispatcher { contract_address };

    // Try to grant staff role by non-superadmin
    start_prank(contract_address, non_admin());
    dispatcher.grant_staff_role(staff());
    stop_prank(contract_address);
}

#[test]
fn test_revoke_staff_role_by_superadmin() {
    // Deploy contract with owner
    let contract_address = deploy_contract(owner());
    let dispatcher = ISpherreDispatcher { contract_address };

    // First grant staff role
    start_prank(contract_address, owner());
    dispatcher.grant_staff_role(staff());

    // Set up event spy for revocation
    let mut spy = spy_events(SpyOn::One(contract_address));

    // Revoke staff role
    dispatcher.revoke_staff_role(staff());
    stop_prank(contract_address);

    // Verify role was revoked
    assert(!dispatcher.has_staff_role(staff()), 'Staff role not revoked');

    // Verify event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Spherre::Event::AccessControlEvent(
                        openzeppelin::access::accesscontrol::AccessControlComponent::Event::RoleRevoked(
                            openzeppelin::access::accesscontrol::AccessControlComponent::RoleRevoked {
                                role: SpherreAdminRoles::STAFF, account: staff(), sender: owner(),
                            },
                        ),
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: ('ERR_NOT_A_SUPERADMIN',))]
fn test_revoke_staff_role_by_non_superadmin() {
    // Deploy contract with owner
    let contract_address = deploy_contract(owner());
    let dispatcher = ISpherreDispatcher { contract_address };

    // First grant staff role
    start_prank(contract_address, owner());
    dispatcher.grant_staff_role(staff());
    stop_prank(contract_address);

    // Try to revoke staff role by non-superadmin
    start_prank(contract_address, non_admin());
    dispatcher.revoke_staff_role(staff());
    stop_prank(contract_address);
}

#[test]
fn test_has_staff_role() {
    // Deploy contract with owner
    let contract_address = deploy_contract(owner());
    let dispatcher = ISpherreDispatcher { contract_address };

    // Grant staff role
    start_prank(contract_address, owner());
    dispatcher.grant_staff_role(staff());
    stop_prank(contract_address);

    // Verify role checks
    assert(dispatcher.has_staff_role(staff()), 'Staff should have role');
    assert(!dispatcher.has_staff_role(non_admin()), 'Non-staff should not have role');
}
