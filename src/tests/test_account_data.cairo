use core::array::ArrayTrait;
use core::starknet::storage::{StoragePathEntry, StoragePointerWriteAccess, MutableVecTrait,};
use crate::account::{SpherreAccount::AccountImpl};
use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait, start_cheat_block_timestamp, stop_cheat_block_timestamp
};


use spherre::tests::mocks::mock_account_data::{
    MockContract, MockContract::PrivateTrait, IMockContractDispatcher, IMockContractDispatcherTrait
};
use spherre::types::{TransactionType, TransactionStatus, MemberDetails};
use starknet::ContractAddress;
use starknet::{contract_address_const, get_block_timestamp};

// Helper function to get addresses
fn deployer() -> ContractAddress {
    contract_address_const::<'deployer'>()
}

fn zero_address() -> ContractAddress {
    contract_address_const::<0>()
}

fn new_member() -> ContractAddress {
    contract_address_const::<'new_member'>()
}

fn another_new_member() -> ContractAddress {
    contract_address_const::<'another_new_member'>()
}

fn third_member() -> ContractAddress {
    contract_address_const::<'third_member'>()
}

fn member() -> ContractAddress {
    contract_address_const::<'member'>()
}

fn deploy_mock_contract() -> IMockContractDispatcher {
    let contract_class = declare("MockContract").unwrap().contract_class();
    let mut calldata = array![];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IMockContractDispatcher { contract_address }
}

fn get_mock_contract_state() -> MockContract::ContractState {
    MockContract::contract_state_for_testing()
}

#[test]
#[should_panic(expected: 'Zero Address Caller')]
fn test_zero_address_caller_should_fail() {
    let zero_address = zero_address();
    let mut state = get_mock_contract_state();
    state.add_member(zero_address);
}

// This indirectly tests get_members_count

#[test]
fn test_add_member() {
    let new_member = new_member();
    let mut state = get_mock_contract_state();
    state.add_member(new_member);
    let count = state.get_members_count();
    assert(count == 1, 'Member not added');
}

#[test]
fn test_get_members() {
    let new_member = new_member();
    let another_new_member = another_new_member();
    let third_member = third_member();
    let mut state = get_mock_contract_state();
    state.add_member(new_member);
    state.add_member(another_new_member);
    state.add_member(third_member);

    let count = state.get_members_count();
    assert(count == 3, 'Members not added');
    let members = state.get_members();
    let member_0 = *members.at(0);
    let member_1 = *members.at(1);
    let member_2 = *members.at(2);
    assert(member_0 == new_member, 'First addition unsuccessful');
    assert(member_1 == another_new_member, 'second addition unsuccessful');
    assert(member_2 == third_member, 'third addition unsuccessful');
}


// Test case to check the successful implementation
// of the set and get threshold logics.
// uses contract state instead of deploying the contract
#[test]
fn test_set_and_get_threshold_sucessful() {
    let mut state = get_mock_contract_state();
    let threshold_val = 2;
    // increase the member count because
    // we can't set a threshold that is greated than member count
    state.edit_member_count(3);
    // call the set_threshold private function
    state.set_threshold(threshold_val);

    let (t_val, mem_count) = state.get_threshold();

    // main check
    assert(t_val == threshold_val, 'invalid threshold');
    assert(mem_count == 3, 'invalid member count');
}

// Test case to check threshold greater than the members count cannot be set
#[test]
#[should_panic]
fn test_cannot_set_threshold_greater_than_members_count() {
    let mut state = get_mock_contract_state();
    let threshold_val = 2;
    // call the set_threshold private function
    // with members_count = 0
    state.set_threshold(threshold_val); // should panic
}

#[test]
fn test_get_transaction() {
    // Initialize contract state
    let mut state = get_mock_contract_state();

    // Define sample transaction data
    let transaction_id: u256 = 1;
    let proposer = contract_address_const::<'proposer'>();
    let executor = contract_address_const::<'executor'>();
    let approver1 = contract_address_const::<'approver1'>();
    let approver2 = contract_address_const::<'approver2'>();
    let rejecter = contract_address_const::<'rejecter'>();
    let date_created = 1617187200;
    let date_executed = 1617190800;

    // Access the storage entry for the transaction
    let storage_path = state.account_data.transactions.entry(transaction_id);

    // Write individual fields of the StorageTransaction
    storage_path.id.write(transaction_id);
    storage_path.tx_type.write(TransactionType::TOKEN_SEND);
    storage_path.tx_status.write(TransactionStatus::APPROVED);
    storage_path.proposer.write(proposer);
    storage_path.executor.write(executor);
    storage_path.date_created.write(date_created);
    storage_path.date_executed.write(date_executed);

    // Append to approved and rejected lists
    storage_path.approved.append().write(approver1);
    storage_path.approved.append().write(approver2);
    storage_path.rejected.append().write(rejecter);

    // Update transaction count
    state.account_data.tx_count.write(transaction_id + 1);

    // Retrieve the transaction using the get_transaction function
    let retrieved_transaction = state.get_transaction(transaction_id);

    // Verify the retrieved transaction matches the expected values
    assert(retrieved_transaction.id == transaction_id, 'Transaction ID mismatch');
    assert(
        retrieved_transaction.tx_type == TransactionType::TOKEN_SEND, 'Transaction type mismatch'
    );
    assert(
        retrieved_transaction.tx_status == TransactionStatus::APPROVED,
        'Transaction status mismatch'
    );
    assert(retrieved_transaction.proposer == proposer, 'Proposer mismatch');
    assert(retrieved_transaction.executor == executor, 'Executor mismatch');
    assert(retrieved_transaction.date_created == date_created, 'Date created mismatch');
    assert(retrieved_transaction.date_executed == date_executed, 'Date executed mismatch');

    // Verify approved and rejected addresses
    assert(retrieved_transaction.approved.len() == 2, 'Approved count mismatch');
    assert(*retrieved_transaction.approved.at(0) == approver1, 'Approver 1 mismatch');
    assert(*retrieved_transaction.approved.at(1) == approver2, 'Approver 2 mismatch');
    assert(retrieved_transaction.rejected.len() == 1, 'Rejected count mismatch');
    assert(*retrieved_transaction.rejected.at(0) == rejecter, 'Rejecter mismatch');
}

#[test]
#[should_panic(expected: 'Transaction is out of range')]
fn test_get_nonexistent_transaction() {
    // Initialize contract state
    let mut state = get_mock_contract_state();

    // Attempt to retrieve a non-existent transaction
    state.get_transaction(u256 { low: 999, high: 0 });
}

#[test]
fn test_is_member() {
    let new_member = new_member();
    let another_new_member = another_new_member();
    let non_member = contract_address_const::<'non_member'>();
    let mut state = get_mock_contract_state();
    state.add_member(new_member);
    state.add_member(another_new_member);
    assert!(state.is_member(new_member), "New member should be recognized as a member");

    assert!(
        state.is_member(another_new_member), "Another new member should be recognized as a member"
    );

    assert!(!state.is_member(non_member), "Non-member should not be recognized as a member");
}

#[test]
fn test_get_number_of_voters() {
    let mut state = get_mock_contract_state();
    let new_member = new_member();
    let another_new_member = another_new_member();
    state.add_member(new_member);
    state.add_member(another_new_member);
    assert(state.get_number_of_voters() == 0, 'voters count should be 0');
    state.assign_voter_permission(new_member);
    state.assign_voter_permission(another_new_member);
    assert(state.get_number_of_voters() == 2, 'voters count should be 2');
}

#[test]
fn test_get_number_of_proposer() {
    let mut state = get_mock_contract_state();
    let new_member = new_member();
    let another_new_member = another_new_member();
    state.add_member(new_member);
    state.add_member(another_new_member);
    assert(state.get_number_of_proposers() == 0, 'voters count should be 0');
    state.assign_proposer_permission(new_member);
    state.assign_proposer_permission(another_new_member);
    assert(state.get_number_of_proposers() == 2, 'voters count should be 2');
}

#[test]
fn test_get_number_of_executors() {
    let mut state = get_mock_contract_state();
    let new_member = new_member();
    let another_new_member = another_new_member();
    state.add_member(new_member);
    state.add_member(another_new_member);
    assert(state.get_number_of_executors() == 0, 'voters count should be 0');
    state.assign_executor_permission(new_member);
    state.assign_executor_permission(another_new_member);
    assert(state.get_number_of_executors() == 2, 'voters count should be 2');
}

#[test]
fn test_create_transaction_successful() {
    let mock_contract = deploy_mock_contract();
    let caller = member();
    // Add Member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    stop_cheat_caller_address(mock_contract.contract_address);
    // Assign Proposer Role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.assign_proposer_permission_pub(caller);
    stop_cheat_caller_address(mock_contract.contract_address);
    // Create Transaction
    start_cheat_caller_address(mock_contract.contract_address, caller);
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);
    stop_cheat_caller_address(mock_contract.contract_address);
    // Get the transaction
    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.tx_type == TransactionType::TOKEN_SEND, 'wrong tx type');
    assert(transaction.proposer == caller, 'wrong proposer');
    assert(transaction.id == tx_id, 'Wrong ID');
    assert(transaction.tx_status == TransactionStatus::INITIATED, 'Wrong Status');
}

#[test]
#[should_panic(expected: 'Caller is not a member')]
fn test_only_member_can_create_transaction() {
    let mock_contract = deploy_mock_contract();
    let caller = member();
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Caller is not a proposer')]
fn test_onlY_member_with_proposer_permission_can_create_transaction() {
    let mock_contract = deploy_mock_contract();
    let caller = member();
    // Add Member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    stop_cheat_caller_address(mock_contract.contract_address);

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
fn test_approve_transaction_successful() {
    let mock_contract = deploy_mock_contract();
    let caller = member();

    // Add Member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);

    // Assign Proposer Role to create transaction
    mock_contract.assign_proposer_permission_pub(caller);

    // Assign voter Role
    mock_contract.assign_voter_permission_pub(caller);

    // Create Transaction
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);

    // Approve Transaction (Should Pass)
    mock_contract.approve_transaction_pub(tx_id, caller);
    stop_cheat_caller_address(mock_contract.contract_address);

    let transaction = mock_contract.get_transaction_pub(tx_id);

    assert(transaction.approved.len() == 1, 'Approvers count should be 1');
    assert(transaction.tx_status == TransactionStatus::APPROVED, 'Transaction should be approved');
}

#[test]
fn test_reject_transaction_successful() {
    let mock_contract = deploy_mock_contract();
    let caller = member();

    // Add Member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);

    // Assign Proposer Role to create transaction
    mock_contract.assign_proposer_permission_pub(caller);

    // Assign voter Role
    mock_contract.assign_voter_permission_pub(caller);

    // Create Transaction
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);

    // Approve Transaction (Should Pass)
    mock_contract.reject_transaction_pub(tx_id, caller);
    stop_cheat_caller_address(mock_contract.contract_address);

    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.rejected.len() == 1, 'Rejecters count should be 1');
    assert(transaction.approved.len() == 0, 'Approvers count should be 1');
}


#[test]
#[should_panic(expected: 'Caller is not a voter')]
fn test_non_voter_cannot_reject_transaction() {
    let mock_contract = deploy_mock_contract();
    let caller = member();
    // Add Member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);

    // Assign Proposer Role to create transaction
    mock_contract.assign_proposer_permission_pub(caller);

    // Create Transaction
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);

    // Approve Transaction (Should Panic)
    mock_contract.reject_transaction_pub(tx_id, caller);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Caller is not a voter')]
fn test_non_voter_cannot_approve_transaction() {
    let mock_contract = deploy_mock_contract();
    let caller = member();
    // Add Member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);

    // Assign Proposer Role to create transaction
    mock_contract.assign_proposer_permission_pub(caller);

    // Create Transaction
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);

    // Approve Transaction (Should Panic)
    mock_contract.approve_transaction_pub(tx_id, caller);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Transaction is not votable')]
fn test_cannot_approve_transaction_with_non_initiated_status() {
    let mock_contract = deploy_mock_contract();
    let caller = member();
    // Add Member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);

    // Assign Proposer Role to create transaction
    mock_contract.assign_proposer_permission_pub(caller);

    // Assign voter Role
    mock_contract.assign_voter_permission_pub(caller);

    // Create Transaction
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);

    // Update Transaction status to EXECUTED
    mock_contract.update_transaction_status(tx_id, TransactionStatus::EXECUTED);

    // Approve Transaction (Should Panic)
    mock_contract.approve_transaction_pub(tx_id, caller);
    stop_cheat_caller_address(mock_contract.contract_address);
}


#[test]
#[should_panic(expected: 'Transaction is not votable')]
fn test_cannot_reject_transaction_with_non_initiated_status() {
    let mock_contract = deploy_mock_contract();
    let caller = member();
    // Add Member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);

    // Assign Proposer Role to create transaction
    mock_contract.assign_proposer_permission_pub(caller);

    // Assign voter Role
    mock_contract.assign_voter_permission_pub(caller);

    // Create Transaction
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);

    // Update Transaction status to EXECUTED
    mock_contract.update_transaction_status(tx_id, TransactionStatus::EXECUTED);

    // Approve Transaction (Should Panic)
    mock_contract.reject_transaction_pub(tx_id, caller);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Transaction is out of range')]
fn test_cannot_approve_unknown_transaction() {
    let mock_contract = deploy_mock_contract();
    let caller = member();
    let tx_id: u256 = 1;
    start_cheat_caller_address(mock_contract.contract_address, caller);
    // Approve Transaction (Should Panic)
    mock_contract.approve_transaction_pub(tx_id, caller);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Transaction is out of range')]
fn test_cannot_reject_unknown_transaction() {
    let mock_contract = deploy_mock_contract();
    let caller = member();
    let tx_id: u256 = 1;
    start_cheat_caller_address(mock_contract.contract_address, caller);
    // Approve Transaction (Should Panic)
    mock_contract.reject_transaction_pub(tx_id, caller);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Caller cannot vote again')]
fn test_cannot_approve_transaction_more_than_once() {
    let mock_contract = deploy_mock_contract();
    let caller = member();
    let new_caller = new_member();
    // Add Member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(new_caller);

    // Assign Proposer Role to create transaction
    mock_contract.assign_proposer_permission_pub(caller);

    // Assign voter Role
    mock_contract.assign_voter_permission_pub(caller);

    // Create Transaction
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);

    // Update Threshold to bypass "Transaction not votable" fail
    mock_contract.set_threshold_pub(2);

    // Approve Transaction (Should Pass)
    mock_contract.approve_transaction_pub(tx_id, caller);

    // Approve Transaction (Should Panic)
    mock_contract.approve_transaction_pub(tx_id, caller);

    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
fn test_execute_transaction_successful() {
    let mock_contract = deploy_mock_contract();
    let caller = member();

    // Add Member
    start_cheat_caller_address(mock_contract.contract_address, caller);

    // Set a non-zero block timestamp for testing
    start_cheat_block_timestamp(mock_contract.contract_address, 1713049189);

    mock_contract.add_member_pub(caller);

    // Assign permissions
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(caller);
    mock_contract.assign_executor_permission_pub(caller);

    // Create Transaction
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);

    // Set threshold to 1 so a single vote will approve
    mock_contract.set_threshold_pub(1);

    // Approve Transaction
    mock_contract.approve_transaction_pub(tx_id, caller);

    // Execute Transaction
    mock_contract.execute_transaction_pub(tx_id, caller);

    stop_cheat_block_timestamp(mock_contract.contract_address);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Verify transaction is executed
    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.tx_status == TransactionStatus::EXECUTED, 'Transaction should be executed');
    assert(transaction.executor == caller, 'Executor should be caller');
    assert(transaction.date_executed > 0, 'Execution date should be set');
}

#[test]
#[should_panic(expected: 'Caller cannot vote again')]
fn test_cannot_reject_transaction_more_than_once() {
    let mock_contract = deploy_mock_contract();
    let caller = member();
    let second_caller = new_member();
    let third_caller = contract_address_const::<'third_caller'>();
    let fourth_caller = contract_address_const::<'fourth_caller'>();
    let fifth_caller = contract_address_const::<'fifth_caller'>();
    // Add Member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(second_caller);
    mock_contract.add_member_pub(third_caller);
    mock_contract.add_member_pub(fourth_caller);
    mock_contract.add_member_pub(fifth_caller);

    // Assign Proposer Role to create transaction
    mock_contract.assign_proposer_permission_pub(caller);

    // Assign voter Role
    mock_contract.assign_voter_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(second_caller);
    mock_contract.assign_voter_permission_pub(third_caller);
    mock_contract.assign_voter_permission_pub(fourth_caller);
    mock_contract.assign_voter_permission_pub(fifth_caller);

    // Create Transaction
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);

    // Update Threshold to bypass "Transaction not votable" fail
    mock_contract.set_threshold_pub(4);

    // Approve Transaction (Should Pass)
    mock_contract.reject_transaction_pub(tx_id, caller);

    // Approve Transaction (Should Panic)
    mock_contract.reject_transaction_pub(tx_id, caller);

    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
fn test_transaction_status_changes_to_rejected() {
    let mock_contract = deploy_mock_contract();
    let caller = member();
    let caller_2 = contract_address_const::<'caller_2'>();
    let caller_3 = contract_address_const::<'caller_3'>();
    let caller_4 = contract_address_const::<'caller_4'>();
    let caller_5 = contract_address_const::<'caller_5'>();
    // Add Member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(caller_2);
    mock_contract.add_member_pub(caller_3);
    mock_contract.add_member_pub(caller_4);
    mock_contract.add_member_pub(caller_5);

    // Assign Proposer Role to create transaction
    mock_contract.assign_proposer_permission_pub(caller);

    // Assign voter Role
    mock_contract.assign_voter_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(caller_2);
    mock_contract.assign_voter_permission_pub(caller_3);
    mock_contract.assign_voter_permission_pub(caller_4);
    mock_contract.assign_voter_permission_pub(caller_5);

    // Create Transaction
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);

    // Update Threshold to bypass "Transaction not votable" fail
    mock_contract.set_threshold_pub(2);

    // Approve Transaction (Should Pass)
    mock_contract.reject_transaction_pub(tx_id, caller);

    stop_cheat_caller_address(mock_contract.contract_address);

    start_cheat_caller_address(mock_contract.contract_address, caller_2);

    mock_contract.assign_voter_permission_pub(caller_2);
    mock_contract.reject_transaction_pub(tx_id, caller_2);

    stop_cheat_caller_address(mock_contract.contract_address);

    start_cheat_caller_address(mock_contract.contract_address, caller_3);

    mock_contract.assign_voter_permission_pub(caller_3);
    mock_contract.reject_transaction_pub(tx_id, caller_3);

    stop_cheat_caller_address(mock_contract.contract_address);

    start_cheat_caller_address(mock_contract.contract_address, caller_4);

    mock_contract.assign_voter_permission_pub(caller_4);
    mock_contract.reject_transaction_pub(tx_id, caller_4);

    stop_cheat_caller_address(mock_contract.contract_address);

    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.rejected.len() == 4, 'Rejections did not go through');
    assert(transaction.tx_status == TransactionStatus::REJECTED, 'Status change error');
}

#[test]
#[should_panic(expected: 'Pausable: paused')]
fn test_blocked_operations_when_paused() {
    let mock = deploy_mock_contract();
    let deployer = contract_address_const::<'member'>();
    let member = member();

    // Setup
    start_cheat_caller_address(mock.contract_address, deployer);
    mock.add_member_pub(member);
    mock.assign_proposer_permission_pub(member);
    mock.assign_voter_permission_pub(member);

    // Create transaction first
    let tx_id = mock.create_transaction_pub(TransactionType::TOKEN_SEND);
    assert(mock.get_transaction_pub(tx_id).id == tx_id, 'Should create tx');

    // Pause and verify blocking
    mock.pause();
    mock.create_transaction_pub(TransactionType::TOKEN_SEND); // Should panic
}

#[test]
fn test_unpaused_operations() {
    let mock = deploy_mock_contract();
    let deployer = contract_address_const::<'member'>();
    let member = member();

    start_cheat_caller_address(mock.contract_address, deployer);
    mock.add_member_pub(member);
    mock.pause();
    mock.unpause();

    // Should work after unpause
    mock.assign_proposer_permission_pub(member);
    let tx_id = mock.create_transaction_pub(TransactionType::TOKEN_SEND);
    assert(mock.get_transaction_pub(tx_id).id == tx_id, 'Should create tx');
}


#[test]
#[should_panic(expected: 'Caller is not a member')]
fn test_non_member_cannot_execute_transaction() {
    let mock_contract = deploy_mock_contract();
    let member_addr = member();
    let non_member = new_member(); // using a different address that's not added as a member

    start_cheat_caller_address(mock_contract.contract_address, member_addr);
    mock_contract.add_member_pub(member_addr);

    mock_contract.assign_proposer_permission_pub(member_addr);
    mock_contract.assign_voter_permission_pub(member_addr);
    mock_contract.assign_executor_permission_pub(member_addr);

    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);

    mock_contract.set_threshold_pub(1);

    mock_contract.approve_transaction_pub(tx_id, member_addr);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Try to execute as non-member (should panic)
    start_cheat_caller_address(mock_contract.contract_address, non_member);
    mock_contract.execute_transaction_pub(tx_id, non_member);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Caller is not an executor')]
fn test_non_executor_cannot_execute_transaction() {
    let mock_contract = deploy_mock_contract();
    let proposer = member();
    let voter = new_member();

    start_cheat_caller_address(mock_contract.contract_address, proposer);
    mock_contract.add_member_pub(proposer);
    mock_contract.add_member_pub(voter);

    // Assign permissions
    mock_contract.assign_proposer_permission_pub(proposer);
    mock_contract.assign_voter_permission_pub(voter);
    // Note: deliberately NOT assigning executor permission to voter

    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);

    mock_contract.set_threshold_pub(1);
    stop_cheat_caller_address(mock_contract.contract_address);

    start_cheat_caller_address(mock_contract.contract_address, voter);
    mock_contract.approve_transaction_pub(tx_id, voter);

    // Try to execute as non-executor (should panic)
    mock_contract.execute_transaction_pub(tx_id, voter);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Transaction is not executable')]
fn test_cannot_execute_non_approved_transaction() {
    let mock_contract = deploy_mock_contract();
    let caller = member();

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);

    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_executor_permission_pub(caller);

    // Create Transaction (status will be INITIATED)
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);

    // Try to execute non-approved transaction (should panic)
    mock_contract.execute_transaction_pub(tx_id, caller);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Transaction is out of range')]
fn test_cannot_execute_nonexistent_transaction() {
    let mock_contract = deploy_mock_contract();
    let caller = member();

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);

    mock_contract.assign_executor_permission_pub(caller);

    // Try to execute non-existent transaction (should panic)
    let non_existent_tx_id: u256 = 999;
    mock_contract.execute_transaction_pub(non_existent_tx_id, caller);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
fn test_approve_transaction_threshold_reached() {
    let mock_contract = deploy_mock_contract();
    let member1 = member();
    let member2 = new_member();
    let member3 = another_new_member();

    // Add members
    start_cheat_caller_address(mock_contract.contract_address, member1);
    mock_contract.add_member_pub(member1);
    mock_contract.add_member_pub(member2);
    mock_contract.add_member_pub(member3);

    // Set threshold to 2
    mock_contract.set_threshold_pub(2);

    // Assign roles
    mock_contract.assign_proposer_permission_pub(member1);
    mock_contract.assign_voter_permission_pub(member1);
    mock_contract.assign_voter_permission_pub(member2);
    mock_contract.assign_voter_permission_pub(member3);

    // Create Transaction
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);

    // First approval - should not reach threshold yet
    mock_contract.approve_transaction_pub(tx_id, member1);

    // Check status - should still be INITIATED
    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.tx_status == TransactionStatus::INITIATED, 'Status should be INITIATED');
    assert(transaction.approved.len() == 1, 'Should have 1 approval');

    // Second approval - should reach threshold
    start_cheat_caller_address(mock_contract.contract_address, member2);
    mock_contract.approve_transaction_pub(tx_id, member2);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Check status - should now be APPROVED
    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.tx_status == TransactionStatus::APPROVED, 'Status should be APPROVED');
    assert(transaction.approved.len() == 2, 'Should have 2 approvals');
}

#[test]
fn test_reject_transaction_forces_rejection() {
    let mock_contract = deploy_mock_contract();
    let member1 = member();
    let member2 = new_member();
    let member3 = another_new_member();
    let member4 = third_member();

    // Add members
    start_cheat_caller_address(mock_contract.contract_address, member1);
    mock_contract.add_member_pub(member1);
    mock_contract.add_member_pub(member2);
    mock_contract.add_member_pub(member3);
    mock_contract.add_member_pub(member4);

    // Set threshold to 3 (out of 4 members)
    mock_contract.set_threshold_pub(3);

    // Assign roles
    mock_contract.assign_proposer_permission_pub(member1);
    mock_contract.assign_voter_permission_pub(member1);
    mock_contract.assign_voter_permission_pub(member2);
    mock_contract.assign_voter_permission_pub(member3);
    mock_contract.assign_voter_permission_pub(member4);

    // Create Transaction
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);

    // First approval
    mock_contract.approve_transaction_pub(tx_id, member1);

    // Check status - should still be INITIATED
    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.tx_status == TransactionStatus::INITIATED, 'Status should be INITIATED');
    assert(transaction.approved.len() == 1, 'Should have 1 approval');

    // Two members reject the transaction
    start_cheat_caller_address(mock_contract.contract_address, member2);
    mock_contract.reject_transaction_pub(tx_id, member2);

    start_cheat_caller_address(mock_contract.contract_address, member3);
    mock_contract.reject_transaction_pub(tx_id, member3);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Check status - should now be REJECTED because even if the last member approves,
    // we can't reach the threshold of 3 approvals
    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.tx_status == TransactionStatus::REJECTED, 'Status should be REJECTED');
    assert(transaction.rejected.len() == 2, 'Should have 2 rejections');
}

#[test]
fn test_member_details_tracking_proposed() {
    let mock_contract = deploy_mock_contract();
    let caller = member();
    start_cheat_block_timestamp(mock_contract.contract_address, 1513049189);

    // Add Member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    stop_cheat_caller_address(mock_contract.contract_address);
    // Assign Proposer Role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.assign_proposer_permission_pub(caller);
    stop_cheat_caller_address(mock_contract.contract_address);
    // Create Transaction
    start_cheat_caller_address(mock_contract.contract_address, caller);
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);
    stop_cheat_caller_address(mock_contract.contract_address);
    // Get Member Details
    let member_details = mock_contract.get_member_full_details_pub(caller);
    assert(member_details.proposed_count == 1, 'wrong proposed count');
    assert(member_details.approved_count == 0, 'wrong approved count');
    assert(member_details.rejected_count == 0, 'wrong rejected count');
    assert(member_details.executed_count == 0, 'wrong executed count');
    assert(member_details.date_joined == 1513049189, 'wrong date joined');
}

#[test]
fn test_member_details_tracking_approved() {
    let mock_contract = deploy_mock_contract();
    let caller_approved = new_member();

    start_cheat_block_timestamp(mock_contract.contract_address, 1513049189);
    // Add Member
    start_cheat_caller_address(mock_contract.contract_address, caller_approved);
    mock_contract.add_member_pub(caller_approved);
    mock_contract.assign_proposer_permission_pub(caller_approved);
    mock_contract.assign_voter_permission_pub(caller_approved);
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);
    mock_contract.approve_transaction_pub(tx_id, caller_approved);
    stop_cheat_caller_address(mock_contract.contract_address);

    let member_details = mock_contract.get_member_full_details_pub(caller_approved);
    assert(member_details.proposed_count == 1, 'wrong proposed count');
    assert(member_details.approved_count == 1, 'wrong approved count');
    assert(member_details.rejected_count == 0, 'wrong rejected count');
    assert(member_details.executed_count == 0, 'wrong executed count');
    assert(member_details.date_joined == 1513049189, 'wrong date joined');
}

#[test]
fn test_member_details_tracking_rejected() {
    let mock_contract = deploy_mock_contract();
    let caller_approved = member();
    start_cheat_block_timestamp(mock_contract.contract_address, 1513049189);

    // Add Member
    start_cheat_caller_address(mock_contract.contract_address, caller_approved);
    mock_contract.add_member_pub(caller_approved);
    mock_contract.assign_proposer_permission_pub(caller_approved);
    mock_contract.assign_voter_permission_pub(caller_approved);
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);
    mock_contract.reject_transaction_pub(tx_id, caller_approved);
    stop_cheat_caller_address(mock_contract.contract_address);

    let member_details = mock_contract.get_member_full_details_pub(caller_approved);
    assert(member_details.proposed_count == 1, 'wrong proposed count');
    assert(member_details.approved_count == 0, 'wrong approved count');
    assert(member_details.rejected_count == 1, 'wrong rejected count');
    assert(member_details.executed_count == 0, 'wrong executed count');
    assert(member_details.date_joined == 1513049189, 'wrong date joined');
}

#[test]
fn test_member_details_tracking_executed() {
    let mock_contract = deploy_mock_contract();
    let caller_executed = member();
    start_cheat_block_timestamp(mock_contract.contract_address, 1513049189);

    start_cheat_caller_address(mock_contract.contract_address, caller_executed);
    start_cheat_block_timestamp(mock_contract.contract_address, 1713049189);

    mock_contract.add_member_pub(caller_executed);

    // Assign permissions
    mock_contract.assign_proposer_permission_pub(caller_executed);
    mock_contract.assign_voter_permission_pub(caller_executed);
    mock_contract.assign_executor_permission_pub(caller_executed);

    // Create Transaction
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);
    mock_contract.set_threshold_pub(1);
    mock_contract.approve_transaction_pub(tx_id, caller_executed);
    mock_contract.execute_transaction_pub(tx_id, caller_executed);

    stop_cheat_block_timestamp(mock_contract.contract_address);
    stop_cheat_caller_address(mock_contract.contract_address);

    let member_details = mock_contract.get_member_full_details_pub(caller_executed);
    assert(member_details.proposed_count == 1, 'wrong proposed count');
    assert(member_details.approved_count == 1, 'wrong approved count');
    assert(member_details.rejected_count == 0, 'wrong rejected count');
    assert(member_details.executed_count == 1, 'wrong executed count');
}

#[should_panic(expected: 'Caller is not a member')]
#[test]
fn test_member_details_tracking_non_member() {
    let mock_contract = deploy_mock_contract();

    // Test non-member access
    let non_member = contract_address_const::<999>();
    let member_details = mock_contract.get_member_full_details_pub(non_member);
}

#[test]
fn test_smart_will_get_member_will_address() {
    let mock_contract = deploy_mock_contract();
    let caller = member();

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    let will_address = contract_address_const::<2>();
    mock_contract.update_smart_will_pub(will_address);
    stop_cheat_caller_address(mock_contract.contract_address);

    let member_will_address = mock_contract.get_member_will_address_pub(caller);
    assert(member_will_address == will_address, 'Will address not set correctly');
}

#[test]
fn test_smart_will_get_member_will_duration() {
    let mock_contract = deploy_mock_contract();
    let caller = member();

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    let will_address = contract_address_const::<2>();
    mock_contract.update_smart_will_pub(will_address);
    stop_cheat_caller_address(mock_contract.contract_address);

    let will_duration = mock_contract.get_member_will_duration_pub(caller);
    assert(will_duration == 7776000, 'Will duration not set correctly');
}

#[test]
fn test_smart_will_get_remaining_will_time() {
    let mock_contract = deploy_mock_contract();
    let caller = member();

    start_cheat_caller_address(mock_contract.contract_address, caller);
    start_cheat_block_timestamp(mock_contract.contract_address, 1000000);

    mock_contract.add_member_pub(caller);
    let will_address = contract_address_const::<2>();
    mock_contract.update_smart_will_pub(will_address);
    stop_cheat_caller_address(mock_contract.contract_address);
    stop_cheat_block_timestamp(mock_contract.contract_address);


    start_cheat_caller_address(mock_contract.contract_address, caller);
    start_cheat_block_timestamp(mock_contract.contract_address, 4000000);
    let remaining_will_time = mock_contract.get_remaining_will_time_pub(caller);
    stop_cheat_block_timestamp(mock_contract.contract_address);
    stop_cheat_caller_address(mock_contract.contract_address);
    assert(remaining_will_time == (7776000 - (4000000 - 1000000)), 'rem will time is incorrect');
}

#[test]
fn test_smart_will_can_update_will() {
    let mock_contract = deploy_mock_contract();
    let caller = member();

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    let can_update_will = mock_contract.can_update_will_pub(caller);
    stop_cheat_caller_address(mock_contract.contract_address);
    assert(can_update_will == true, 'Can update will Incorrect');

    start_cheat_caller_address(mock_contract.contract_address, caller);
    let will_address = contract_address_const::<2>();
    mock_contract.update_smart_will_pub(will_address);

    let can_update_will = mock_contract.can_update_will_pub(caller);
    stop_cheat_caller_address(mock_contract.contract_address);
    assert(can_update_will == true, 'Can update will Incorrect');

}

#[test]
fn test_smart_will_can_update_will_time() {
    let mock_contract = deploy_mock_contract();
    let caller = member();

    start_cheat_caller_address(mock_contract.contract_address, caller);
    start_cheat_block_timestamp(mock_contract.contract_address, 100000);

    mock_contract.add_member_pub(caller);
    let will_address = contract_address_const::<2>();
    mock_contract.update_smart_will_pub(will_address);
    let can_update_will = mock_contract.can_update_will_pub(caller);

    stop_cheat_block_timestamp(mock_contract.contract_address);
    stop_cheat_caller_address(mock_contract.contract_address);

    assert(can_update_will == true, 'Can update will Incorrect');

    start_cheat_caller_address(mock_contract.contract_address, caller);
    start_cheat_block_timestamp(mock_contract.contract_address, 100001 + 7776000);

    let can_update_will = mock_contract.can_update_will_pub(caller);
    stop_cheat_block_timestamp(mock_contract.contract_address);
    stop_cheat_caller_address(mock_contract.contract_address);
    assert(can_update_will == false, 'Can update will Incorrect');
}

#[test]
#[should_panic(expected: 'Caller is not a member')]
fn test_smart_will_can_update_will_non_member() {
    let mock_contract = deploy_mock_contract();
    let non_member = new_member();

    start_cheat_caller_address(mock_contract.contract_address, non_member);
    let can_update_will = mock_contract.can_update_will_pub(non_member);
    stop_cheat_caller_address(mock_contract.contract_address);
}