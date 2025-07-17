use MockPermissionContract::InternalTrait;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use spherre::components::permission_control::PermissionControl;
use spherre::interfaces::ipermission_control::{
    IPermissionControl, IPermissionControlDispatcher, IPermissionControlDispatcherTrait,
};

use spherre::tests::utils::{MEMBER_ONE};
use spherre::types::{PermissionEnum, PermissionTrait, Permissions};
#[starknet::contract]
pub mod MockPermissionContract {
    use spherre::components::permission_control::PermissionControl;
    use starknet::ContractAddress;

    component!(
        path: PermissionControl, storage: permission_control_storage, event: PermissionControlEvent,
    );

    #[abi(embed_v0)]
    pub impl PermissionControlImpl =
        PermissionControl::PermissionControl<ContractState>;

    pub impl PermissionControlInternalImpl = PermissionControl::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub permission_control_storage: PermissionControl::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        PermissionControlEvent: PermissionControl::Event,
    }


    #[generate_trait]
    pub impl InternalImpl of InternalTrait {
        fn assign_proposer_permission(ref self: ContractState, member: ContractAddress) {
            self.permission_control_storage.assign_proposer_permission(member);
        }

        fn assign_voter_permission(ref self: ContractState, member: ContractAddress) {
            self.permission_control_storage.assign_voter_permission(member);
        }
        fn assign_executor_permission(ref self: ContractState, member: ContractAddress) {
            self.permission_control_storage.assign_executor_permission(member);
        }
        fn revoke_proposer_permission(ref self: ContractState, member: ContractAddress) {
            self.permission_control_storage.revoke_proposer_permission(member);
        }

        fn revoke_voter_permission(ref self: ContractState, member: ContractAddress) {
            self.permission_control_storage.revoke_voter_permission(member);
        }
        fn revoke_executor_permission(ref self: ContractState, member: ContractAddress) {
            self.permission_control_storage.revoke_executor_permission(member);
        }
        fn assign_all_permissions(ref self: ContractState, member: ContractAddress) {
            self.permission_control_storage.assign_all_permissions(member);
        }
        fn revoke_all_permissions(ref self: ContractState, member: ContractAddress) {
            self.permission_control_storage.revoke_all_permissions(member);
        }
    }
}
// use MockPermissionContract::{PermissionControlInternalImpl::InternalTrait};

/// Deploy mock permission contract and return the dispatcher
fn deploy_contract() -> IPermissionControlDispatcher {
    let contract = declare("MockPermissionContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    let dispatcher = IPermissionControlDispatcher { contract_address };
    dispatcher
}

fn get_contract_state() -> MockPermissionContract::ContractState {
    MockPermissionContract::contract_state_for_testing()
}

fn get_component_state() -> PermissionControl::ComponentState<
    MockPermissionContract::ContractState,
> {
    PermissionControl::component_state_for_testing()
}

type TestingState = PermissionControl::ComponentState<MockPermissionContract::ContractState>;

impl TestingStateDefault of Default<TestingState> {
    fn default() -> TestingState {
        PermissionControl::component_state_for_testing()
    }
}


/// Testcase for the assign_proposer_permission logic.
/// assign proposer permission to member and
/// check if member has proposer permission.
#[test]
fn test_assign_proposer_permission() {
    let member = MEMBER_ONE();
    let mut state = get_contract_state();
    // assign the proposer permission
    state.assign_proposer_permission(member);
    // check whether member has proposer permission
    let check = state.has_permission(member, Permissions::PROPOSER);
    assert(check, 'no proposer permission');
}

/// Testcase for the assign_voter_permission logic.
/// assign voter permission to member and
/// check if member has voter permission.
#[test]
fn test_assign_voter_permission() {
    let member = MEMBER_ONE();
    let mut state = get_contract_state();
    // assign the voter permission
    state.assign_voter_permission(member);
    // check whether member has voter permission
    let check = state.has_permission(member, Permissions::VOTER);
    assert(check, 'no voter permission');
}

/// Testcase for the assign_executor_permission logic.
/// assign executor permission to member and
/// check if member has executor permission.
#[test]
fn test_assign_executor_permission() {
    let member = MEMBER_ONE();
    let mut state = get_contract_state();
    // assign the executor permission
    state.assign_executor_permission(member);
    // check whether member has executor permission
    let check = state.has_permission(member, Permissions::EXECUTOR);
    assert(check, 'no executor permission');
}

/// Testcase for the revoke_proposer_permission logic.
/// revoke proposer permission to member and
/// check if member no longer has proposer permission.
#[test]
fn test_revoke_proposer_permission() {
    let member = MEMBER_ONE();
    let mut state = get_contract_state();
    // assign the proposer permission
    state.assign_proposer_permission(member);
    // check whether member has proposer permission
    let check = state.has_permission(member, Permissions::PROPOSER);
    assert(check, 'no proposer permission');
    // revoke the proposer permission
    state.revoke_proposer_permission(member);
    // check whether member no longer has proposer permission
    let check = state.has_permission(member, Permissions::PROPOSER);
    assert(!check, 'proposer permission exists');
}

/// Testcase for the revoke_voter_permission logic.
/// revoke voter permission to member and
/// check if member no longer has voter permission.
#[test]
fn test_revoke_voter_permission() {
    let member = MEMBER_ONE();
    let mut state = get_contract_state();
    // assign the voter permission
    state.assign_voter_permission(member);
    // check whether member has voter permission
    let check = state.has_permission(member, Permissions::VOTER);
    assert(check, 'no voter permission');
    // revoke the voter permission
    state.revoke_voter_permission(member);
    // check whether member no longer has voter permission
    let check = state.has_permission(member, Permissions::VOTER);
    assert(!check, 'voter permission exists');
}

/// Testcase for the revoke_executor_permission logic.
/// revoke executor permission to member and
/// check if member no longer has executor permission.
#[test]
fn test_revoke_executor_permission() {
    let member = MEMBER_ONE();
    let mut state = get_contract_state();
    // assign the executor permission
    state.assign_executor_permission(member);
    // check whether member has executor permission
    let check = state.has_permission(member, Permissions::EXECUTOR);
    assert(check, 'no executor permission');
    // revoke the executor permission
    state.revoke_executor_permission(member);
    // check whether member no longer has executor permission
    let check = state.has_permission(member, Permissions::EXECUTOR);
    assert(!check, 'executor permission exists');
}

/// Testcase for the get_member_permissions logic.
/// adds to a member all the permissions and
/// returns and array with all the permissions of
/// the member.
#[test]
fn test_get_member_permissions() {
    let member = MEMBER_ONE();
    let mut state = get_contract_state();
    // assign the member all the permissions
    state.assign_proposer_permission(member);
    state.assign_executor_permission(member);
    state.assign_voter_permission(member);

    let permissions: Array<PermissionEnum> = state.get_member_permissions(member);

    let proposer = *permissions.at(0);
    let executor = *permissions.at(1);
    let voter = *permissions.at(2);

    // check if the member has all the permissions
    assert(proposer == PermissionEnum::PROPOSER, 'proposer permission not found');
    assert(executor == PermissionEnum::EXECUTOR, 'executor permission not found');
    assert(voter == PermissionEnum::VOTER, 'voter permission not found');
}

/// Testcase for the assign_all_permissions logic.
/// adds to a member all the permissions and
/// check if the member has it
#[test]
fn test_assign_all_permissions() {
    let member = MEMBER_ONE();
    let mut state = get_contract_state();
    // assign the member all the permissions
    state.assign_all_permissions(member);

    // check if the member has all the permissions
    assert(state.has_permission(member, Permissions::PROPOSER), 'proposer permission not found');
    assert(state.has_permission(member, Permissions::EXECUTOR), 'executor permission not found');
    assert(state.has_permission(member, Permissions::VOTER), 'voter permission not found');
}

/// Testcase for the revoke_all_permissions logic.
/// revokes all the permissions the member has and
/// check does not have them
#[test]
fn test_revoke_all_permissions() {
    let member = MEMBER_ONE();
    let mut state = get_contract_state();
    // assign the member all the permissions
    state.assign_all_permissions(member);

    // check if the member has all the permissions
    assert(state.has_permission(member, Permissions::PROPOSER), 'proposer permission not found');
    assert(state.has_permission(member, Permissions::EXECUTOR), 'executor permission not found');
    assert(state.has_permission(member, Permissions::VOTER), 'voter permission not found');

    // revoke all the permissions
    state.revoke_all_permissions(member);

    // check that the member does not have the permissions
    assert(!state.has_permission(member, Permissions::PROPOSER), 'proposer permission found');
    assert(!state.has_permission(member, Permissions::EXECUTOR), 'executor permission found');
    assert(!state.has_permission(member, Permissions::VOTER), 'voter permission found');
}


#[test]
fn test_permission_to_mask() {
    let contract_dispatcher = deploy_contract();
    // this value represents having the PROPOSER and VOTER PERMISSION
    let mask_for_proposer_voter: u8 = 3;
    let permissions: Array<PermissionEnum> = array![
        PermissionEnum::PROPOSER, PermissionEnum::VOTER,
    ];

    let mask = contract_dispatcher.permissions_to_mask(permissions);
    assert(mask == mask_for_proposer_voter, 'Invalid mask value');

    let permissions: Array<PermissionEnum> = array![PermissionEnum::PROPOSER];
    let mask = contract_dispatcher.permissions_to_mask(permissions);
    assert(mask != mask_for_proposer_voter, 'Mask should be different');
    assert(mask == PermissionEnum::PROPOSER.to_mask(), 'Mask should be different');
}

#[test]
fn test_permission_from_mask() {
    let contract_dispatcher = deploy_contract();
    // this value represents having the PROPOSER, VOTER and EXECUTOR PERMISSION
    let mask_for_proposer_voter_executor: u8 = 7;

    let permissions: Array<PermissionEnum> = contract_dispatcher
        .permissions_from_mask(mask_for_proposer_voter_executor);
    assert(permissions.len() == 3, 'Invalid Permissions Length');
    assert(*permissions.at(0) == PermissionEnum::PROPOSER, 'wrong permission at index 0');
    assert(*permissions.at(1) == PermissionEnum::VOTER, 'wrong permission at index 1');
    assert(*permissions.at(2) == PermissionEnum::EXECUTOR, 'wrong permission at index 2');

    // this value represents having the PROPOSER and EXECUTOR PERMISSION
    let mask_for_proposer_executor: u8 = 5;

    let permissions: Array<PermissionEnum> = contract_dispatcher
        .permissions_from_mask(mask_for_proposer_executor);
    assert(permissions.len() == 2, 'Invalid Permissions Length');
    assert(*permissions.at(0) == PermissionEnum::PROPOSER, 'wrong permission at index 0');
    assert(*permissions.at(1) == PermissionEnum::EXECUTOR, 'wrong permission at index 1');
}

#[test]
fn test_is_valid_mask() {
    // this value represents having the VOTER and EXECUTOR PERMISSION
    let valid_mask: u8 = 6;
    let invalid_mask: u8 = 8;

    let contract_dispatcher = deploy_contract();
    assert(contract_dispatcher.is_valid_mask(valid_mask), 'Mask should be valid');
    assert(!contract_dispatcher.is_valid_mask(invalid_mask), 'Mask should be invalid');
}
