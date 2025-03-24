use core::array::ArrayTrait;
use core::starknet::storage::{StoragePathEntry, StoragePointerWriteAccess, MutableVecTrait,};
use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait
};

use spherre::interfaces::iaccount_data::{IAccountDataDispatcher, IAccountDataDispatcherTrait};

use spherre::tests::mocks::mock_account_data::{MockContract, MockContract::PrivateTrait};
use spherre::types::{TransactionType, TransactionStatus};
use starknet::ContractAddress;
use starknet::contract_address_const;

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

fn deploy_mock_contract() -> ContractAddress {
    let contract_class = declare("MockContract").unwrap().contract_class();
    let mut calldata = array![];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    contract_address
}

fn get_mock_contract_state() -> MockContract::ContractState {
    MockContract::contract_state_for_testing()
}

#[test]
#[should_panic(expected: 'Zero Address Caller')]
fn test_zero_address_caller_should_fail() {
    let zero_address = zero_address();
    let member = member();
    let contract_address = deploy_mock_contract();

    let mock_contract_dispatcher = IAccountDataDispatcher { contract_address };
    // let mock_contract_internal_dispatcher = IAccountDataDispatcherTrait { contract_address };
    start_cheat_caller_address(contract_address, member);
    mock_contract_dispatcher.add_member(zero_address);
    stop_cheat_caller_address(contract_address);
}

// This indirectly tests get_members_count

#[test]
fn test_add_member() {
    let new_member = new_member();
    let member = member();
    let contract_address = deploy_mock_contract();

    let mock_contract_dispatcher = IAccountDataDispatcher { contract_address };
    start_cheat_caller_address(contract_address, member);
    mock_contract_dispatcher.add_member(new_member);
    stop_cheat_caller_address(contract_address);

    let count = mock_contract_dispatcher.get_members_count();
    assert(count == 1, 'Member not added');
}

#[test]
fn test_get_members() {
    let new_member = new_member();
    let another_new_member = another_new_member();
    let third_member = third_member();
    let member = member();
    let contract_address = deploy_mock_contract();

    let mock_contract_dispatcher = IAccountDataDispatcher { contract_address };
    start_cheat_caller_address(contract_address, member);
    mock_contract_dispatcher.add_member(new_member);
    mock_contract_dispatcher.add_member(another_new_member);
    mock_contract_dispatcher.add_member(third_member);
    stop_cheat_caller_address(contract_address);

    let count = mock_contract_dispatcher.get_members_count();
    assert(count == 3, 'Members not added');
    let members = mock_contract_dispatcher.get_account_members();
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
    let transaction_id = u256 { low: 1, high: 0 };
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
    state.account_data.tx_count.write(transaction_id + u256 { low: 1, high: 0 });

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
#[should_panic(expected: 'Transaction ID out of range')]
fn test_get_nonexistent_transaction() {
    // Initialize contract state
    let mut state = get_mock_contract_state();

    // Attempt to retrieve a non-existent transaction
    state.get_transaction(u256 { low: 999, high: 0 });
}
