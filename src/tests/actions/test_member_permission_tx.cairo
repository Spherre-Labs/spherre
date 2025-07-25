use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address, EventSpyTrait
};
use spherre::account_data::{AccountData, AccountData::{TransactionExecuted, TransactionApproved}};
use spherre::actions::member_permission_tx::{
    MemberPermissionTransaction, MemberPermissionTransaction::PermissionEditExecuted
};
use spherre::tests::mocks::mock_account_data::{
    IMockContractDispatcher, IMockContractDispatcherTrait,
};
use spherre::types::{Permissions, TransactionStatus, TransactionType};
use starknet::get_block_timestamp;
use starknet::{ContractAddress, contract_address_const};

fn deploy_mock_contract() -> IMockContractDispatcher {
    let contract_class = declare("MockContract").unwrap().contract_class();
    let mut calldata = array![];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IMockContractDispatcher { contract_address }
}

fn proposer() -> ContractAddress {
    contract_address_const::<'proposer'>()
}

fn member_to_edit() -> ContractAddress {
    contract_address_const::<'member_to_edit'>()
}

// --- PROPOSAL TESTS ---

#[test]
// Test successful proposal of a member permission edit transaction
fn test_propose_member_permission_transaction_successful() {
    let mock_contract = deploy_mock_contract();

    let caller: ContractAddress = proposer();
    let member: ContractAddress = member_to_edit();
    let new_permissions: u8 = 6; // VOTER and EXECUTOR permissions

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose member permission transaction
    let tx_id = mock_contract.propose_edit_permission_transaction_pub(member, new_permissions);
    stop_cheat_caller_address(mock_contract.contract_address);

    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(
        transaction.tx_type == TransactionType::MEMBER_PERMISSION_EDIT, 'Invalid Transaction Type',
    );

    let perm_transaction = mock_contract.get_edit_permission_transaction_pub(tx_id);
    assert(perm_transaction.member == member, 'Member Address Invalid');
    assert(perm_transaction.new_permissions == new_permissions, 'Permissions Invalid');
}

#[test]
#[should_panic(expected: 'Member address is zero')]
// Test proposal fails if member address is zero
fn test_propose_member_permission_transaction_fail_with_zero_member() {
    let mock_contract = deploy_mock_contract();

    let caller: ContractAddress = proposer();
    let member: ContractAddress = 0.try_into().unwrap(); // Zero Address
    let new_permissions: u8 = 6;

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose member permission transaction - should panic
    mock_contract.propose_edit_permission_transaction_pub(member, new_permissions);
}

#[test]
#[should_panic(expected: 'Permission mask is invalid')]
// Test proposal fails if permission mask is invalid
fn test_propose_member_permission_transaction_fail_with_invalid_permission() {
    let mock_contract = deploy_mock_contract();

    let caller: ContractAddress = proposer();
    let member: ContractAddress = member_to_edit();
    let invalid_permissions: u8 = 8; // Invalid permission mask

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose member permission transaction - should panic
    mock_contract.propose_edit_permission_transaction_pub(member, invalid_permissions);
}

#[test]
#[should_panic(expected: 'Member does not exist')]
// Test proposal fails if member does not exist
fn test_propose_member_permission_transaction_fail_with_non_member() {
    let mock_contract = deploy_mock_contract();

    let caller: ContractAddress = proposer();
    let non_member: ContractAddress = member_to_edit();
    let new_permissions: u8 = 6;

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose member permission transaction - should panic
    mock_contract.propose_edit_permission_transaction_pub(non_member, new_permissions);
}

#[test]
#[should_panic(expected: 'Permission unchanged')]
// Test proposal fails if new permissions are the same as current permissions
fn test_propose_member_permission_transaction_fail_with_same_permissions() {
    let mock_contract = deploy_mock_contract();

    let caller: ContractAddress = proposer();
    let member: ContractAddress = member_to_edit();
    let initial_permissions: u8 = 6; // VOTER and EXECUTOR permissions

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(member);
    mock_contract.assign_executor_permission_pub(member);

    // Propose member permission transaction with same permissions - should panic
    mock_contract.propose_edit_permission_transaction_pub(member, initial_permissions);
}

#[test]
#[should_panic(expected: 'Transaction is out of range')]
// Test fails if trying to get a non-existent transaction
fn test_get_member_permission_transaction_nonexistent() {
    let mock_contract = deploy_mock_contract();
    let nonexistent_id = 999_u256;

    // This should panic as the transaction doesn't exist
    mock_contract.get_edit_permission_transaction_pub(nonexistent_id);
}

#[test]
// Test successful retrieval of a member permission transaction
fn test_get_member_permission_transaction_success() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let member = member_to_edit();
    let new_permissions: u8 = 6;

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    mock_contract.assign_proposer_permission_pub(caller);

    // Create a member permission transaction
    let tx_id = mock_contract.propose_edit_permission_transaction_pub(member, new_permissions);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Test getting the member permission transaction
    let permission_transaction = mock_contract.get_edit_permission_transaction_pub(tx_id);
    assert(permission_transaction.member == member, 'Wrong member address');
    assert(permission_transaction.new_permissions == new_permissions, 'Wrong permissions');
}


#[test]
// Test successful execution of a member permission transaction
fn test_execute_member_permission_transaction_success() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let member = member_to_edit();
    let new_permissions: u8 = 6;

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(caller);
    mock_contract.assign_executor_permission_pub(caller);
    // Assign member permissions
    mock_contract.assign_proposer_permission_pub(member);
    mock_contract.assign_voter_permission_pub(member);
    mock_contract.assign_executor_permission_pub(member);

    // check whether member has permissions
    assert(
        mock_contract.has_permission_pub(member, Permissions::PROPOSER),
        'should have proposer permission',
    );
    assert(
        mock_contract.has_permission_pub(member, Permissions::VOTER),
        'should have voter permission',
    );
    assert(
        mock_contract.has_permission_pub(member, Permissions::EXECUTOR),
        'should have executor permission',
    );

    // Create a member permission transaction
    let tx_id = mock_contract.propose_edit_permission_transaction_pub(member, new_permissions);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Test getting the member permission transaction
    let permission_transaction = mock_contract.get_edit_permission_transaction_pub(tx_id);
    assert(permission_transaction.member == member, 'Wrong member address');
    assert(permission_transaction.new_permissions == new_permissions, 'Wrong permissions');

    // Approve the transaction
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.approve_transaction_pub(tx_id, caller);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Execute the transaction
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.execute_edit_permission_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Checks
    let transaction = mock_contract.get_transaction_pub(tx_id);
    // check that the transaction status is EXECUTED
    assert(transaction.tx_status == TransactionStatus::EXECUTED, 'Invalid Status');

    assert(
        !mock_contract.has_permission_pub(member, Permissions::PROPOSER),
        'proposer permission found',
    );
    assert(
        mock_contract.has_permission_pub(member, Permissions::VOTER),
        'should have voter permission',
    );
    assert(
        mock_contract.has_permission_pub(member, Permissions::EXECUTOR),
        'should have executor permission',
    );
}

// --- EXECUTION EDGE CASE TESTS ---

#[test]
#[should_panic(expected: 'Transaction is out of range')]
// Test execution fails if transaction does not exist
fn test_execute_edit_permission_transaction_fail_nonexistent() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let nonexistent_id = 999_u256;
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.execute_edit_permission_transaction_pub(nonexistent_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Invalid edit permission txn')]
// Test execution fails if transaction is not a permission edit transaction
fn test_execute_edit_permission_transaction_fail_wrong_type() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(caller); // assign voter permission
    // Propose a different type of transaction (e.g., threshold change)
    let tx_id = mock_contract.create_transaction_pub(TransactionType::THRESHOLD_CHANGE);
    mock_contract.approve_transaction_pub(tx_id, caller);
    mock_contract.execute_edit_permission_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Caller is not an executor')]
// Test execution fails if caller is not an executor
fn test_execute_edit_permission_transaction_fail_not_executor() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let member = member_to_edit();
    let new_permissions: u8 = 6;
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(caller); // FIX: assign voter permission
    // Propose and approve transaction, but do not assign executor permission to caller
    let tx_id = mock_contract.propose_edit_permission_transaction_pub(member, new_permissions);
    mock_contract.approve_transaction_pub(tx_id, caller);
    mock_contract.execute_edit_permission_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Member does not exist')]
// Test execution fails if the target member does not exist
fn test_execute_edit_permission_transaction_fail_member_not_exist() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let member = member_to_edit();
    let new_permissions: u8 = 6;
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    let tx_id = mock_contract.propose_edit_permission_transaction_pub(member, new_permissions);
    mock_contract.approve_transaction_pub(tx_id, caller);
    // Remove member before execution
    // (Assume a remove_member_pub exists or simulate by not adding member)
    stop_cheat_caller_address(mock_contract.contract_address);
    start_cheat_caller_address(mock_contract.contract_address, caller);
    // Try to execute for non-member
    mock_contract.execute_edit_permission_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Permission mask is invalid')]
// Test execution fails if the new permission mask is invalid
fn test_execute_edit_permission_transaction_fail_invalid_permission_mask() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let member = member_to_edit();
    let invalid_permissions: u8 = 8; // Invalid mask
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    mock_contract.assign_proposer_permission_pub(caller);
    let tx_id = mock_contract.propose_edit_permission_transaction_pub(member, invalid_permissions);
    mock_contract.approve_transaction_pub(tx_id, caller);
    mock_contract.execute_edit_permission_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Transaction is not executable')]
// Test execution fails if the transaction has not been approved
fn test_execute_edit_permission_transaction_fail_not_approved() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let member = member_to_edit();
    let new_permissions: u8 = 6;
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    mock_contract.assign_proposer_permission_pub(caller);
    let tx_id = mock_contract.propose_edit_permission_transaction_pub(member, new_permissions);
    // Do not approve
    mock_contract.execute_edit_permission_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

// --- EVENT EMISSION TESTS ---

#[test]
// Test that TransactionApproved event is emitted correctly when a transaction is approved
fn test_event_emitted_transaction_approved() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let member = member_to_edit();
    let new_permissions: u8 = 6;
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(caller); // FIX: assign voter permission
    let tx_id = mock_contract.propose_edit_permission_transaction_pub(member, new_permissions);
    let mut spy = spy_events();
    mock_contract.approve_transaction_pub(tx_id, caller);
    stop_cheat_caller_address(mock_contract.contract_address);
    // let transaction_date_approved = mock_contract.get_transaction_pub(tx_id).date_approved;
    let transaction_date_approved = get_block_timestamp();
    let expected_event = AccountData::Event::TransactionApproved(
        TransactionApproved { transaction_id: tx_id, date_approved: transaction_date_approved, },
    );
    spy.assert_emitted(@array![(mock_contract.contract_address, expected_event)]);
}

#[test]
// Test that TransactionExecuted event is emitted correctly when a transaction is executed
fn test_event_emitted_transaction_executed() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let member = member_to_edit();
    let new_permissions: u8 = 6;
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_executor_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(caller); // FIX: assign voter permission
    let tx_id = mock_contract.propose_edit_permission_transaction_pub(member, new_permissions);
    mock_contract.approve_transaction_pub(tx_id, caller);
    let mut spy = spy_events();
    mock_contract.execute_edit_permission_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);

    let transaction_date_executed = mock_contract.get_transaction_pub(tx_id).date_executed;
    let expected_event = AccountData::Event::TransactionExecuted(
        TransactionExecuted {
            transaction_id: tx_id, executor: caller, date_executed: transaction_date_executed,
        }
    );
    spy.assert_emitted(@array![(mock_contract.contract_address, expected_event)]);
}

#[test]
// Test that PermissionEditExecuted event is emitted correctly when a member's permissions are
// edited
fn test_event_emitted_permission_edit_executed() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let member = member_to_edit();
    let new_permissions: u8 = 6;
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_executor_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(caller); // FIX: assign voter permission
    let tx_id = mock_contract.propose_edit_permission_transaction_pub(member, new_permissions);
    mock_contract.approve_transaction_pub(tx_id, caller);
    let mut spy = spy_events();
    mock_contract.execute_edit_permission_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
    let expected_event = MemberPermissionTransaction::Event::PermissionEditExecuted(
        PermissionEditExecuted { transaction_id: tx_id, member, new_permissions },
    );
    spy.assert_emitted(@array![(mock_contract.contract_address, expected_event)]);
}

