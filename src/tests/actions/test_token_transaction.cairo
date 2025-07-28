use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address, spy_events, EventSpyTrait, EventSpyAssertionsTrait,
};
use spherre::account_data::AccountData;
use spherre::actions::token_transaction::TokenTransaction;
use spherre::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use spherre::tests::mocks::mock_account_data::{
    IMockContractDispatcher, IMockContractDispatcherTrait,
};
use spherre::tests::mocks::mock_token::{IMockTokenDispatcher, IMockTokenDispatcherTrait};
use spherre::types::{TransactionStatus, TransactionType};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp};

fn deploy_mock_token() -> IERC20Dispatcher {
    let contract_class = declare("MockToken").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IERC20Dispatcher { contract_address }
}

fn deploy_mock_contract() -> IMockContractDispatcher {
    let contract_class = declare("MockContract").unwrap().contract_class();
    let mut calldata = array![];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IMockContractDispatcher { contract_address }
}

fn owner() -> ContractAddress {
    contract_address_const::<'owner'>()
}
fn recipient() -> ContractAddress {
    contract_address_const::<'recipient'>()
}

fn approver1() -> ContractAddress {
    contract_address_const::<'approver1'>()
}

fn approver2() -> ContractAddress {
    contract_address_const::<'approver2'>()
}

fn executor() -> ContractAddress {
    contract_address_const::<'executor'>()
}

// Helper function to setup a member with all permissions
fn setup_member_with_all_permissions(
    mock_contract: IMockContractDispatcher, member: ContractAddress
) {
    start_cheat_caller_address(mock_contract.contract_address, member);
    mock_contract.add_member_pub(member);
    mock_contract.assign_proposer_permission_pub(member);
    mock_contract.assign_voter_permission_pub(member);
    mock_contract.assign_executor_permission_pub(member);
    stop_cheat_caller_address(mock_contract.contract_address);
}

// Helper function to setup multiple members with specific permissions
fn setup_multiple_members(
    mock_contract: IMockContractDispatcher,
    members: Array<ContractAddress>,
    with_proposer: bool,
    with_voter: bool,
    with_executor: bool,
) {
    let mut i = 0;
    loop {
        if i >= members.len() {
            break;
        }
        let member = *members.at(i);

        start_cheat_caller_address(mock_contract.contract_address, member);
        mock_contract.add_member_pub(member);

        if with_proposer {
            mock_contract.assign_proposer_permission_pub(member);
        }
        if with_voter {
            mock_contract.assign_voter_permission_pub(member);
        }
        if with_executor {
            mock_contract.assign_executor_permission_pub(member);
        }

        stop_cheat_caller_address(mock_contract.contract_address);
        i += 1;
    }
}

// Helper function to mint tokens to mock contract and setup basic permissions
fn setup_token_and_permissions(
    mock_contract: IMockContractDispatcher,
    token: IERC20Dispatcher,
    member: ContractAddress,
    mint_amount: u256,
) {
    // Mint tokens
    let mock_token = IMockTokenDispatcher { contract_address: token.contract_address };
    mock_token.mint(mock_contract.contract_address, mint_amount);

    // Setup member permissions
    setup_member_with_all_permissions(mock_contract, member);
}

// Helper to create a transaction that will consume balance (for insufficient balance tests)
fn balance_consuming_transaction(
    mock_contract: IMockContractDispatcher,
    token: IERC20Dispatcher,
    caller: ContractAddress,
    amount: u256,
) {
    let temp_recipient = contract_address_const::<'temp_recipient'>();

    start_cheat_caller_address(mock_contract.contract_address, caller);
    let temp_tx_id = mock_contract
        .propose_token_transaction_pub(token.contract_address, amount, temp_recipient);
    mock_contract.approve_transaction_pub(temp_tx_id, caller);
    mock_contract.execute_token_transaction_pub(temp_tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}


#[test]
#[should_panic(expected: 'Recipient address is zero')]
fn test_propose_token_transaction_fail_zero_recipient() {
    let mock_contract = deploy_mock_contract();
    let token = deploy_mock_token();
    let amount: u256 = 100;
    let caller = owner();
    let zero_recipient: ContractAddress = contract_address_const::<0x0>();

    setup_token_and_permissions(mock_contract, token, caller, 1000);

    start_cheat_caller_address(mock_contract.contract_address, caller);

    // This should panic
    mock_contract.propose_token_transaction_pub(token.contract_address, amount, zero_recipient);

    stop_cheat_caller_address(mock_contract.contract_address);
}


// Test to execute non-existent token transaction
// This test is expected to panic since the transaction does not exist
#[test]
#[should_panic(expected: 'Transaction is out of range')]
fn test_execute_token_transaction_fail_non_existent() {
    let mock_contract = deploy_mock_contract();
    let caller: ContractAddress = owner();
    let non_existent_tx_id: u256 = 999;

    setup_member_with_all_permissions(mock_contract, caller);

    start_cheat_caller_address(mock_contract.contract_address, caller);
    // Try to execute non-existent transaction, should panic!
    mock_contract.execute_token_transaction_pub(non_existent_tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

// Use Member Add Transaction to test execute_token_transaction failure
// This test is expected to panic since the transaction type is not TOKEN_SEND
#[test]
#[should_panic(expected: 'Invalid Token Transaction Type')]
fn test_execute_token_transaction_fail_invalid_type() {
    let mock_contract = deploy_mock_contract();
    let caller: ContractAddress = owner();
    let new_member: ContractAddress = recipient();

    setup_member_with_all_permissions(mock_contract, caller);

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.set_threshold_pub(1);

    // Create a MEMBER_ADD transaction (not TOKEN_SEND)
    let invalid_tx_id = mock_contract.propose_member_add_transaction_pub(new_member, 1_u8);

    // Execute as token transaction, should fail because tx_type != TOKEN_SEND
    mock_contract.execute_token_transaction_pub(invalid_tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

// This test checks the execution of a token transaction with insufficient approvals
// It should panic because the threshold is not met
#[test]
#[should_panic(expected: 'Transaction is not executable')]
fn test_execute_token_transaction_fail_insufficient_approvals() {
    let mock_contract = deploy_mock_contract();
    let token = deploy_mock_token();
    let amount_to_mint: u256 = 10000000;
    let amount_to_send: u256 = 100000;
    let caller: ContractAddress = owner();
    let voter1: ContractAddress = approver1();
    let receiver: ContractAddress = recipient();

    setup_token_and_permissions(mock_contract, token, caller, amount_to_mint);
    // Add a second member with voting permissions
    setup_member_with_all_permissions(mock_contract, voter1);

    start_cheat_caller_address(mock_contract.contract_address, caller);
    // Set threshold to 2
    mock_contract.set_threshold_pub(2);

    // Propose transaction
    let tx_id = mock_contract
        .propose_token_transaction_pub(token.contract_address, amount_to_send, receiver);

    // Only approve with 1 member (caller) when threshold requires 2
    mock_contract.approve_transaction_pub(tx_id, caller);

    // Execute without sufficient approvals, should panic with "Transaction is not executable"
    mock_contract.execute_token_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

// This test checks the execution of a token transaction with an unauthorized executor
#[test]
#[should_panic(expected: 'Caller is not an executor')]
fn test_execute_token_transaction_fail_unauthorized_executor() {
    let mock_contract = deploy_mock_contract();
    let token = deploy_mock_token();
    let amount_to_mint: u256 = 10000000;
    let amount_to_send: u256 = 100000;
    let proposer: ContractAddress = owner();
    let unauthorized_caller: ContractAddress = recipient();
    let receiver: ContractAddress = contract_address_const::<'other_recipient'>();

    setup_token_and_permissions(mock_contract, token, proposer, amount_to_mint);

    // Setup proposer and approve transaction
    start_cheat_caller_address(mock_contract.contract_address, proposer);
    mock_contract.set_threshold_pub(1);

    let tx_id = mock_contract
        .propose_token_transaction_pub(token.contract_address, amount_to_send, receiver);
    mock_contract.approve_transaction_pub(tx_id, proposer);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Add unauthorized caller as member but without executor permission
    start_cheat_caller_address(mock_contract.contract_address, unauthorized_caller);
    mock_contract.add_member_pub(unauthorized_caller);

    // Try to execute with unauthorized caller, this should panic!
    mock_contract.execute_token_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

// This test checks the execution of a token transaction with insufficient balance at execution
#[test]
#[should_panic(expected: 'Insufficient token amount')]
fn test_execute_token_transaction_fail_insufficient_balance_at_execution() {
    let mock_contract = deploy_mock_contract();
    let token = deploy_mock_token();
    let amount_to_mint: u256 = 100000;
    let amount_to_send: u256 = 60000;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    setup_token_and_permissions(mock_contract, token, caller, amount_to_mint);

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.set_threshold_pub(1);

    // Propose and approve first transaction
    let tx_id = mock_contract
        .propose_token_transaction_pub(token.contract_address, amount_to_send, receiver);
    mock_contract.approve_transaction_pub(tx_id, caller);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Create another transaction that consumes most of the balance
    balance_consuming_transaction(mock_contract, token, caller, 70000);

    // Try to execute the original transaction, tiss should panic due to insufficient balance
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.execute_token_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

// This test checks the full lifecycle of a token transaction with event emissions
// It includes proposing, approving, executing, and verifying events
#[test]
fn test_full_token_transaction_lifecycle_with_events() {
    let mock_contract = deploy_mock_contract();
    let token = deploy_mock_token();
    let amount_to_mint: u256 = 10000000;
    let amount_to_send: u256 = 100000;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    setup_token_and_permissions(mock_contract, token, caller, amount_to_mint);

    // Event spy setup
    let mut spy = spy_events();

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.set_threshold_pub(1);

    // Propose transaction
    let tx_id = mock_contract
        .propose_token_transaction_pub(token.contract_address, amount_to_send, receiver);

    // Verify proposal event
    let expected_proposal_event = TokenTransaction::Event::TokenTransactionProposed(
        TokenTransaction::TokenTransactionProposed {
            id: tx_id, token: token.contract_address, amount: amount_to_send, recipient: receiver
        }
    );
    spy.assert_emitted(@array![(mock_contract.contract_address, expected_proposal_event)]);

    // Approve transaction
    mock_contract.approve_transaction_pub(tx_id, caller);

    // Verify approval event
    let expected_approval_event = AccountData::Event::TransactionApproved(
        AccountData::TransactionApproved {
            transaction_id: tx_id, date_approved: get_block_timestamp()
        }
    );
    spy.assert_emitted(@array![(mock_contract.contract_address, expected_approval_event)]);

    // Execute transaction
    mock_contract.execute_token_transaction_pub(tx_id);

    // Verify execution event
    let expected_execution_event = TokenTransaction::Event::TokenTransactionExecuted(
        TokenTransaction::TokenTransactionExecuted {
            id: tx_id, token: token.contract_address, amount: amount_to_send, recipient: receiver
        }
    );
    spy.assert_emitted(@array![(mock_contract.contract_address, expected_execution_event)]);

    stop_cheat_caller_address(mock_contract.contract_address);
}

// This test checks the approval event emission when a transaction is approved
#[test]
fn test_approve_transaction_event_emission() {
    let mock_contract = deploy_mock_contract();
    let token = deploy_mock_token();
    let amount_to_mint: u256 = 10000000;
    let amount_to_send: u256 = 100000;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    setup_token_and_permissions(mock_contract, token, caller, amount_to_mint);

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.set_threshold_pub(1);

    // Propose transaction
    let tx_id = mock_contract
        .propose_token_transaction_pub(token.contract_address, amount_to_send, receiver);

    // Setup spy after proposal
    let mut spy = spy_events();

    // Approve transaction
    mock_contract.approve_transaction_pub(tx_id, caller);

    stop_cheat_caller_address(mock_contract.contract_address);

    // Verify approval event was emitted
    let events = spy.get_events();
    assert(events.events.len() >= 1, 'Approval event not emitted');

    // Verify transaction state changed to approved
    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.approved.len() >= 1, 'Transaction not approved');
}

// This test checks the scenario where multiple approvals are made before execution
#[test]
fn test_multiple_approvals_before_execution() {
    let mock_contract = deploy_mock_contract();
    let token = deploy_mock_token();
    let amount_to_mint: u256 = 10000000;
    let amount_to_send: u256 = 100000;
    let proposer: ContractAddress = owner();
    let voter1: ContractAddress = approver1();
    let voter2: ContractAddress = approver2();
    let executor_member: ContractAddress = executor();
    let receiver: ContractAddress = recipient();

    setup_token_and_permissions(mock_contract, token, proposer, amount_to_mint);

    let mut spy = spy_events();

    // Setup all members using helper function
    let members = array![voter1, voter2, executor_member];
    setup_multiple_members(mock_contract, members, false, true, true);

    // Set threshold to require 2 approvals
    start_cheat_caller_address(mock_contract.contract_address, proposer);
    mock_contract.set_threshold_pub(2);

    // Propose transaction
    let tx_id = mock_contract
        .propose_token_transaction_pub(token.contract_address, amount_to_send, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);

    // First approval
    start_cheat_caller_address(mock_contract.contract_address, voter1);
    mock_contract.approve_transaction_pub(tx_id, voter1);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Second approval
    start_cheat_caller_address(mock_contract.contract_address, voter2);
    mock_contract.approve_transaction_pub(tx_id, voter2);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Execute transaction
    start_cheat_caller_address(mock_contract.contract_address, executor_member);
    mock_contract.execute_token_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Verify final state
    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.tx_status == TransactionStatus::EXECUTED, 'Transaction not executed');
    assert(token.balance_of(receiver) == amount_to_send, 'Incorrect recipient balance');
    assert(transaction.approved.len() >= 2, 'Insufficient approvals recorded');

    // Verify events hould have proposal, 2 approvals, and execution events
    let events = spy.get_events();
    assert(events.events.len() >= 4, 'Insufficient events lifecycle');
}

// This test checks the scenario where a transaction is executed twice
#[test]
#[should_panic(expected: 'Transaction is not executable')]
fn test_execute_token_transaction_fail_already_executed() {
    let mock_contract = deploy_mock_contract();
    let token = deploy_mock_token();
    let amount_to_mint: u256 = 10000000;
    let amount_to_send: u256 = 100000;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    setup_token_and_permissions(mock_contract, token, caller, amount_to_mint);

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.set_threshold_pub(1);

    let tx_id = mock_contract
        .propose_token_transaction_pub(token.contract_address, amount_to_send, receiver);
    mock_contract.approve_transaction_pub(tx_id, caller);
    mock_contract.execute_token_transaction_pub(tx_id);

    // Try to execute again, should panic
    mock_contract.execute_token_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Amount is invalid')]
fn test_propose_token_transaction_fail_zero_amount() {
    let mock_contract = deploy_mock_contract();
    let token = deploy_mock_token();
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    setup_member_with_all_permissions(mock_contract, caller);

    start_cheat_caller_address(mock_contract.contract_address, caller);
    // Try to propose with zero amount - should panic
    mock_contract.propose_token_transaction_pub(token.contract_address, 0, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Pausable: paused')]
fn test_pause_contract_prevents_execution() {
    let mock_contract = deploy_mock_contract();
    let token = deploy_mock_token();
    let amount_to_mint: u256 = 10000000;
    let amount_to_send: u256 = 100000;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    setup_token_and_permissions(mock_contract, token, caller, amount_to_mint);

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.set_threshold_pub(1);

    // Propose and approve transaction
    let tx_id = mock_contract
        .propose_token_transaction_pub(token.contract_address, amount_to_send, receiver);
    mock_contract.approve_transaction_pub(tx_id, caller);

    // Pause the contract
    mock_contract.pause();

    // After pausing, try to execute - should panic!
    mock_contract.execute_token_transaction_pub(tx_id);

    // Verify contract is paused and transaction cannot be executed
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
fn test_propose_transaction_successful() {
    let mock_contract = deploy_mock_contract();
    let token = deploy_mock_token();
    let amount_to_mint: u256 = 10000000;
    let amount_to_send: u256 = 100000;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();
    // Mint token for account
    let mock_token = IMockTokenDispatcher { contract_address: token.contract_address };
    mock_token.mint(mock_contract.contract_address, amount_to_mint);

    //
    // propose transaction functionality
    //
    // add member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    // Assign Proposer Role
    mock_contract.assign_proposer_permission_pub(caller);
    // Propose Transaction
    let tx_id = mock_contract
        .propose_token_transaction_pub(token.contract_address, amount_to_send, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Checks
    // get transaction
    let transaction = mock_contract.get_transaction_pub(tx_id);
    // check that the transaction type is type TOKEN::SEND
    assert(transaction.tx_type == TransactionType::TOKEN_SEND, 'Invalid Transaction');
    let token_transaction = mock_contract.get_token_transaction_pub(tx_id);
    assert(token_transaction.token == token.contract_address, 'Contract Address Invalid');
    assert(token_transaction.amount == amount_to_send, 'Amount is Invalid');
    assert(token_transaction.recipient == receiver, 'Recipient is Invalid');
}

#[test]
#[should_panic(expected: 'Caller is not a proposer')]
fn test_propose_transaction_fail_if_not_proposer() {
    let mock_contract = deploy_mock_contract();
    let token = deploy_mock_token();
    let amount_to_mint: u256 = 10000000;
    let amount_to_send: u256 = 100000;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint token for account
    let mock_token = IMockTokenDispatcher { contract_address: token.contract_address };
    mock_token.mint(mock_contract.contract_address, amount_to_mint);

    // Proposer transaction
    // add member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);

    // Propose Transaction
    mock_contract
        .propose_token_transaction_pub(
            token.contract_address, amount_to_send, receiver,
        ); // should panic
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Insufficient token amount')]
fn test_propose_transaction_fail_if_balance_is_insufficient() {
    let mock_contract = deploy_mock_contract();
    let token = deploy_mock_token();
    let amount_to_send: u256 = 100000;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Proposer transaction
    // add member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    // Assign Proposer Role
    mock_contract.assign_proposer_permission_pub(caller);
    // Propose Transaction
    mock_contract
        .propose_token_transaction_pub(
            token.contract_address, amount_to_send, receiver,
        ); // should panic
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Recipient cannot be account')]
fn test_propose_transaction_fail_if_recipient_is_account() {
    let mock_contract = deploy_mock_contract();
    let token = deploy_mock_token();
    let amount_to_send: u256 = 100000;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = mock_contract.contract_address;

    // Proposer transaction
    // add member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    // Assign Proposer Role
    mock_contract.assign_proposer_permission_pub(caller);
    // Propose Transaction
    mock_contract
        .propose_token_transaction_pub(
            token.contract_address, amount_to_send, receiver,
        ); // should panic
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
fn test_execute_token_transaction_successful() {
    let mock_contract = deploy_mock_contract();
    let token = deploy_mock_token();
    let amount_to_mint: u256 = 10000000;
    let amount_to_send: u256 = 100000;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();
    // Mint token for account
    let mock_token = IMockTokenDispatcher { contract_address: token.contract_address };
    mock_token.mint(mock_contract.contract_address, amount_to_mint);

    //
    // propose transaction functionality
    //
    // add member
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
    let tx_id = mock_contract
        .propose_token_transaction_pub(token.contract_address, amount_to_send, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Checks
    // get transaction
    let transaction = mock_contract.get_transaction_pub(tx_id);
    // check that the transaction type is type TOKEN::SEND
    assert(transaction.tx_type == TransactionType::TOKEN_SEND, 'Invalid Transaction');
    let token_transaction = mock_contract.get_token_transaction_pub(tx_id);
    assert(token_transaction.token == token.contract_address, 'Contract Address Invalid');
    assert(token_transaction.amount == amount_to_send, 'Amount is Invalid');
    assert(token_transaction.recipient == receiver, 'Recipient is Invalid');

    // Approve Transaction
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.approve_transaction_pub(tx_id, caller);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Execute the transaction
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.execute_token_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Checks
    let transaction = mock_contract.get_transaction_pub(tx_id);
    // check that the transaction status is EXECUTED
    assert(transaction.tx_status == TransactionStatus::EXECUTED, 'Invalid Status');

    // check that the balance of the token in the receiver is the token transaction balance
    assert(token.balance_of(receiver) == amount_to_send, 'Invalid balance');
}
