use core::array::ArrayTrait;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use spherre::actions::change_threshold_transaction::ChangeThresholdTransaction;
use spherre::account_data::AccountData;

use spherre::tests::mocks::mock_account_data::{
    IMockContractDispatcher, IMockContractDispatcherTrait, MockContract,
};
use spherre::types::{TransactionStatus, TransactionType};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp};

// test utility functions
fn deploy_mock_contract() -> IMockContractDispatcher {
    let contract_class = declare("MockContract").unwrap().contract_class();
    let mut calldata = array![];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IMockContractDispatcher { contract_address }
}

fn proposer() -> ContractAddress {
    contract_address_const::<'proposer'>()
}

fn executor() -> ContractAddress {
    contract_address_const::<'executor'>()
}

fn zero_address() -> ContractAddress {
    contract_address_const::<0>()
}

fn set_voters(mock_contract: IMockContractDispatcher, members: Array<ContractAddress>) {
    for member in members {
        mock_contract.add_member_pub(member);
        mock_contract.assign_voter_permission_pub(member);
    };
}

fn get_members(num: u64) -> Array<ContractAddress> {
    let mut addresses: Array<ContractAddress> = array![];
    let n = num + 1;
    for i in 1
        ..n {
            let k: felt252 = i.try_into().unwrap();
            let adr: ContractAddress = k.try_into().unwrap();
            addresses.append(adr);
        };
    addresses
}

// component specific test cases
#[test]
fn test_propose_threshold_change_transaction_successful() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let current_threshold: u64 = 3;
    let new_threshold: u64 = 4;

    // Set up threshold and voters
    start_cheat_caller_address(mock_contract.contract_address, caller);
    let voters = get_members(5); // Simulate 5 voters
    set_voters(mock_contract, voters);

    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(caller);
    mock_contract.set_threshold_pub(current_threshold);

    // Spy on events
    let mut spy = spy_events();

    // Propose threshold change transaction
    let tx_id = mock_contract.propose_threshold_change_transaction_pub(new_threshold);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Verify transaction
    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.tx_type == TransactionType::THRESHOLD_CHANGE, 'Invalid Transaction');
    assert(transaction.tx_status == TransactionStatus::INITIATED, 'Invalid Status');
    assert(transaction.proposer == caller, 'Invalid Proposer');

    // Verify threshold change data
    let threshold_data = mock_contract.get_threshold_change_transaction_pub(tx_id);
    assert(threshold_data.new_threshold == new_threshold, 'Invalid New Threshold');

    // Verify event
    spy
        .assert_emitted(
            @array![
                (
                    mock_contract.contract_address,
                    MockContract::Event::ChangeThresholdEvent(
                        ChangeThresholdTransaction::Event::ThresholdChangeProposed(
                            ChangeThresholdTransaction::ThresholdChangeProposed {
                                id: tx_id, new_threshold,
                            }
                        ),
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: 'Caller is not a proposer')]
fn test_propose_threshold_change_transaction_fail_if_not_proposer() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let current_threshold: u64 = 3;
    let new_threshold: u64 = 4;

    // Set up threshold and voters, but don’t assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    let voters = get_members(5);
    set_voters(mock_contract, voters);

    mock_contract.add_member_pub(caller);
    mock_contract.set_threshold_pub(current_threshold);

    // Propose threshold change transaction (should fail)
    mock_contract.propose_threshold_change_transaction_pub(new_threshold);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Threshold must be > 0')]
fn test_propose_threshold_change_transaction_fail_if_zero_threshold() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let current_threshold: u64 = 3;
    let new_threshold: u64 = 0;

    // Set up threshold and voters
    start_cheat_caller_address(mock_contract.contract_address, caller);
    let voters = get_members(5);
    set_voters(mock_contract, voters);

    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.set_threshold_pub(current_threshold);

    // Propose threshold change transaction with zero threshold (should fail)
    mock_contract.propose_threshold_change_transaction_pub(new_threshold);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Threshold is unchanged')]
fn test_propose_threshold_change_transaction_fail_if_same_threshold() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let current_threshold: u64 = 3;
    let new_threshold: u64 = 3;

    // Set up threshold and voters
    start_cheat_caller_address(mock_contract.contract_address, caller);
    let voters = get_members(5);
    set_voters(mock_contract, voters);

    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.set_threshold_pub(current_threshold);

    // Propose threshold change transaction with same threshold (should fail)
    mock_contract.propose_threshold_change_transaction_pub(new_threshold);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Threshold exceeds total voters')]
fn test_propose_threshold_change_transaction_fail_if_excessive_threshold() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let current_threshold: u64 = 3;
    let new_threshold: u64 = 12;

    // Set up threshold and voters
    start_cheat_caller_address(mock_contract.contract_address, caller);
    let voters = get_members(5);
    set_voters(mock_contract, voters);

    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.set_threshold_pub(current_threshold);

    // Propose threshold change transaction with excessive threshold (should fail)
    mock_contract.propose_threshold_change_transaction_pub(new_threshold);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic]
fn test_propose_threshold_change_transaction_fail_if_paused() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let current_threshold: u64 = 3;
    let new_threshold: u64 = 4;

    // Set up threshold and voters
    start_cheat_caller_address(mock_contract.contract_address, caller);
    let voters = get_members(5);
    set_voters(mock_contract, voters);

    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.set_threshold_pub(current_threshold);

    // Pause the contract
    mock_contract.pause();

    // Propose threshold change transaction (should fail)
    mock_contract.propose_threshold_change_transaction_pub(new_threshold);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Invalid threshold transaction')]
fn test_get_threshold_change_transaction_fail_if_invalid_type() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Create a TOKEN_SEND transaction
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);

    // Attempt to retrieve as threshold change transaction (should fail)
    mock_contract.get_threshold_change_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic]
fn test_get_threshold_change_transaction_fail_if_non_existent() {
    let mock_contract = deploy_mock_contract();

    // Attempt to retrieve a non-existent transaction
    mock_contract.get_threshold_change_transaction_pub(999);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
fn test_get_all_threshold_change_transactions() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let current_threshold: u64 = 3;

    // Set up threshold and voters
    start_cheat_caller_address(mock_contract.contract_address, caller);
    let voters = get_members(5);
    set_voters(mock_contract, voters);

    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.set_threshold_pub(current_threshold);

    // Propose two threshold change transactions
    let _tx_id1 = mock_contract.propose_threshold_change_transaction_pub(4);
    let _tx_id2 = mock_contract.propose_threshold_change_transaction_pub(2);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Retrieve all transactions
    let transactions = mock_contract.get_all_threshold_change_transactions_pub();
    assert(transactions.len() == 2, 'Incorrect transaction count');
    assert(*transactions.at(0).new_threshold == 4, 'Incorrect first threshold');
    assert(*transactions.at(1).new_threshold == 2, 'Incorrect second threshold');
}

#[test]
fn test_execute_change_threshold_successful() {
    let mock_contract = deploy_mock_contract();
    let caller: ContractAddress = proposer();
    let new_threshold: u64 = 3;
    let members = get_members(5);
    set_voters(mock_contract, members); // Set up voters

    //
    // propose transaction functionality
    //
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    // Assign Proposer Role
    mock_contract.assign_proposer_permission_pub(caller);
    // Assign Voter Role
    mock_contract.assign_voter_permission_pub(caller);
    // Assign Executor Role
    mock_contract.assign_executor_permission_pub(caller);
    // Set Threshold
    mock_contract.set_threshold_pub(1);
    // Propose Transaction
    let tx_id = mock_contract.propose_threshold_change_transaction_pub(new_threshold);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Checks
    // get transaction
    let transaction = mock_contract.get_transaction_pub(tx_id);
    // check that the transaction type is type TOKEN::SEND
    assert(transaction.tx_type == TransactionType::THRESHOLD_CHANGE, 'Invalid Transaction');
    let change_threshold_transaction = mock_contract.get_threshold_change_transaction_pub(tx_id);
    assert(change_threshold_transaction.new_threshold == new_threshold, 'Invalid New Threshold');

    // Approve Transaction
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.approve_transaction_pub(tx_id, caller);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Execute the transaction
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.execute_threshold_change_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Checks
    let transaction = mock_contract.get_transaction_pub(tx_id);
    // check that the transaction status is EXECUTED
    assert(transaction.tx_status == TransactionStatus::EXECUTED, 'Invalid Status');

    // check that the threshold has been updated
    let (updated_threshold, _) = mock_contract.get_threshold_pub();
    assert(updated_threshold == new_threshold, 'Threshold not updated correctly');
}

#[test]
#[should_panic(expected: 'Invalid threshold transaction')]
fn test_execute_change_threshold_fail_invalid_transaction_type() {
    let mock_contract = deploy_mock_contract();
    let caller = executor();
    
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_executor_permission_pub(caller);
    
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);
    
    mock_contract.execute_threshold_change_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic]
fn test_execute_change_threshold_fail_nonexistent_transaction() {
    let mock_contract = deploy_mock_contract();
    let caller = executor();
    
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_executor_permission_pub(caller);
    
    // Try to execute a non-existent transaction
    let non_existent_tx_id: u256 = 999;
    mock_contract.execute_threshold_change_transaction_pub(non_existent_tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Caller is not an executor')]
fn test_execute_change_threshold_fail_not_executor() {
    let mock_contract = deploy_mock_contract();
    let proposer_addr = proposer();
    let non_executor = contract_address_const::<'non_executor'>();
    let new_threshold: u64 = 3;
    let members = get_members(5);
    set_voters(mock_contract, members);

    // Set up and propose transaction with proposer
    start_cheat_caller_address(mock_contract.contract_address, proposer_addr);
    mock_contract.add_member_pub(proposer_addr);
    mock_contract.assign_proposer_permission_pub(proposer_addr);
    mock_contract.assign_voter_permission_pub(proposer_addr);
    mock_contract.set_threshold_pub(1);
    let tx_id = mock_contract.propose_threshold_change_transaction_pub(new_threshold);
    
    // Approve transaction
    mock_contract.approve_transaction_pub(tx_id, proposer_addr);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Try to execute with non-executor (should fail)
    start_cheat_caller_address(mock_contract.contract_address, non_executor);
    mock_contract.add_member_pub(non_executor);
    mock_contract.execute_threshold_change_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Threshold must be > 0')]
fn test_execute_change_threshold_fail_zero_threshold() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let zero_threshold: u64 = 0;
    let members = get_members(5);
    set_voters(mock_contract, members);

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(caller);
    mock_contract.assign_executor_permission_pub(caller);
    mock_contract.set_threshold_pub(1);
    
    let tx_id = mock_contract.create_transaction_pub(TransactionType::THRESHOLD_CHANGE);
    mock_contract.approve_transaction_pub(tx_id, caller);
    
    mock_contract.execute_threshold_change_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Threshold exceeds total voters')]
fn test_execute_change_threshold_fail_exceeds_voters() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let members = get_members(3); // Only 3 voters
    let excessive_threshold: u64 = 5; // More than number of voters
    set_voters(mock_contract, members);

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(caller);
    mock_contract.assign_executor_permission_pub(caller);
    mock_contract.set_threshold_pub(1);
    
    let tx_id = mock_contract.propose_threshold_change_transaction_pub(excessive_threshold);
    mock_contract.approve_transaction_pub(tx_id, caller);
    
    // Should fail because threshold exceeds number of voters
    mock_contract.execute_threshold_change_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Transaction is not executable')]
fn test_execute_change_threshold_fail_not_approved() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let new_threshold: u64 = 3;
    let members = get_members(5);
    set_voters(mock_contract, members);

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_executor_permission_pub(caller);
    mock_contract.set_threshold_pub(2); // Higher threshold
    
    let tx_id = mock_contract.propose_threshold_change_transaction_pub(new_threshold);
    
    mock_contract.execute_threshold_change_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic]
fn test_execute_change_threshold_fail_when_paused() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let new_threshold: u64 = 3;
    let members = get_members(5);
    set_voters(mock_contract, members);

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(caller);
    mock_contract.assign_executor_permission_pub(caller);
    mock_contract.set_threshold_pub(1);
    
    let tx_id = mock_contract.propose_threshold_change_transaction_pub(new_threshold);
    mock_contract.approve_transaction_pub(tx_id, caller);
    
    mock_contract.pause();
    
    // Should fail because contract is paused
    mock_contract.execute_threshold_change_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
fn test_execute_change_threshold_with_complete_event_validation() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let new_threshold: u64 = 4;
    let members = get_members(5);
    set_voters(mock_contract, members);

    // Set up event spy
    let mut spy = spy_events();

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(caller);
    mock_contract.assign_executor_permission_pub(caller);
    mock_contract.set_threshold_pub(1);
    
    // Step 1: Propose transaction
    let tx_id = mock_contract.propose_threshold_change_transaction_pub(new_threshold);
    
    // Verify ThresholdChangeProposed event
    spy.assert_emitted(
        @array![
            (
                mock_contract.contract_address,
                                                   MockContract::Event::ChangeThresholdEvent(
                      ChangeThresholdTransaction::Event::ThresholdChangeProposed(
                          ChangeThresholdTransaction::ThresholdChangeProposed {
                              id: tx_id, 
                              new_threshold
                          }
                      )
                  )
            )
        ]
    );

    // Step 2: Approve transaction
    mock_contract.approve_transaction_pub(tx_id, caller);
    
      spy.assert_emitted(
          @array![
              (
                  mock_contract.contract_address,
                  MockContract::Event::AccountDataEvent(
                      AccountData::Event::TransactionApproved(
                          AccountData::TransactionApproved {
                              transaction_id: tx_id, 
                              date_approved: get_block_timestamp()
                          }
                      )
                  )
              )
          ]
      );

    // Step 3: Execute transaction
    mock_contract.execute_threshold_change_transaction_pub(tx_id);
    
      spy.assert_emitted(
          @array![
              (
                  mock_contract.contract_address,
                  MockContract::Event::AccountDataEvent(
                      AccountData::Event::TransactionExecuted(
                          AccountData::TransactionExecuted {
                              transaction_id: tx_id,
                              executor: caller,
                              date_executed: get_block_timestamp()
                          }
                      )
                  )
              )
          ]
      );

      spy.assert_emitted(
          @array![
              (
                  mock_contract.contract_address,
                  MockContract::Event::ChangeThresholdEvent(
                      ChangeThresholdTransaction::Event::ThresholdChangeExecuted(
                          ChangeThresholdTransaction::ThresholdChangeExecuted {
                              id: tx_id, 
                              new_threshold
                          }
                      )
                  )
              )
          ]
      );
    
    stop_cheat_caller_address(mock_contract.contract_address);

    let (updated_threshold, _) = mock_contract.get_threshold_pub();
    assert(updated_threshold == new_threshold, 'Threshold not updated');
}

#[test]
fn test_multiple_approvers_complete_flow_with_events() {
    let mock_contract = deploy_mock_contract();
    let proposer_addr = proposer();
    let executor_addr = executor();
    let voter1 = contract_address_const::<'voter1'>();
    let voter2 = contract_address_const::<'voter2'>();
    let new_threshold: u64 = 2;
    
    let members = array![proposer_addr, executor_addr, voter1, voter2];
    set_voters(mock_contract, members);

    let mut spy = spy_events();

    start_cheat_caller_address(mock_contract.contract_address, proposer_addr);
    mock_contract.add_member_pub(proposer_addr);
    mock_contract.assign_proposer_permission_pub(proposer_addr);
    mock_contract.assign_voter_permission_pub(proposer_addr);
    mock_contract.set_threshold_pub(3); // Require 3 approvals
    
    let tx_id = mock_contract.propose_threshold_change_transaction_pub(new_threshold);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Approve with multiple voters
    start_cheat_caller_address(mock_contract.contract_address, proposer_addr);
    mock_contract.approve_transaction_pub(tx_id, proposer_addr);
    stop_cheat_caller_address(mock_contract.contract_address);

    start_cheat_caller_address(mock_contract.contract_address, voter1);
    mock_contract.approve_transaction_pub(tx_id, voter1);
    stop_cheat_caller_address(mock_contract.contract_address);

    start_cheat_caller_address(mock_contract.contract_address, voter2);
    mock_contract.approve_transaction_pub(tx_id, voter2);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Setup executor and execute
    start_cheat_caller_address(mock_contract.contract_address, executor_addr);
    mock_contract.add_member_pub(executor_addr);
    mock_contract.assign_executor_permission_pub(executor_addr);
    mock_contract.execute_threshold_change_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);

    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.tx_status == TransactionStatus::EXECUTED, 'Should be executed');
    assert(transaction.executor == executor_addr, 'Wrong executor');
    
    let (updated_threshold, _) = mock_contract.get_threshold_pub();
    assert(updated_threshold == new_threshold, 'Threshold not updated');

    // Verify ThresholdChangeExecuted event was emitted
      spy.assert_emitted(
          @array![
              (
                  mock_contract.contract_address,
                  MockContract::Event::ChangeThresholdEvent(
                      ChangeThresholdTransaction::Event::ThresholdChangeExecuted(
                          ChangeThresholdTransaction::ThresholdChangeExecuted {
                              id: tx_id, 
                              new_threshold
                          }
                      )
                  )
              )
          ]
      );
}
