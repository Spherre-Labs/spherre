use core::array::ArrayTrait;
use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait, EventSpy, spy_events, EventSpyAssertionsTrait,
};
use spherre::actions::change_threshold_transaction::ChangeThresholdTransaction;
use spherre::interfaces::ichange_threshold_tx::{
    IChangeThresholdTransactionDispatcher, IChangeThresholdTransactionDispatcherTrait
};
use spherre::tests::mocks::mock_account_data::{
    MockContract, IMockContractDispatcher, IMockContractDispatcherTrait,
};
use spherre::types::{TransactionType, Transaction, ThresholdChangeData, TransactionStatus};
use starknet::{ContractAddress, contract_address_const};

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
                                id: tx_id, proposer: caller, new_threshold
                            }
                        )
                    )
                )
            ]
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
    let caller = proposer();

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
