use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use spherre::actions::token_transaction::TokenTransaction;
use spherre::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use spherre::interfaces::itoken_tx::ITokenTransaction;
use spherre::tests::mocks::mock_account_data::{
    IMockContractDispatcher, IMockContractDispatcherTrait,
};
use spherre::tests::mocks::mock_token::{IMockTokenDispatcher, IMockTokenDispatcherTrait};
use spherre::types::{TransactionStatus, TransactionType};
use starknet::{ContractAddress, contract_address_const};

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

#[test]
fn test_propose_token_transaction() {
    // Setup the test environment
    let mock_contract = deploy_mock_contract();
    let token = deploy_mock_token();
    let amount_to_mint: u256 = 10000000;
    let amount_to_send: u256 = 100000;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint tokens for the contract
    let mock_token = IMockTokenDispatcher { contract_address: token.contract_address };
    mock_token.mint(mock_contract.contract_address, amount_to_mint);

    // Setup access control - Focus on proper role assignment
    start_cheat_caller_address(mock_contract.contract_address, caller);

    // Add member
    mock_contract.add_member_pub(caller);

    // Verify caller doesn't have proposer role yet
    let has_proposer_role = mock_contract.is_proposer_pub(caller);
    assert(!has_proposer_role, 'Should not have proposer role yet');

    // Assign Proposer Role - this is the key access control step
    mock_contract.assign_proposer_permission_pub(caller);

    // Verify caller now has proposer role
    let has_proposer_role = mock_contract.is_proposer_pub(caller);
    assert(has_proposer_role, 'Should have proposer role now');

    // Propose Transaction
    let tx_id = mock_contract
        .propose_token_transaction_pub(token.contract_address, amount_to_send, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Verify transaction was created with correct parameters
    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.tx_type == TransactionType::TOKEN_SEND, 'Invalid Transaction type');

    let token_transaction = mock_contract.get_token_transaction_pub(tx_id);
    assert(token_transaction.token == token.contract_address, 'Wrong token address');
    assert(token_transaction.amount == amount_to_send, 'Wrong amount');
    assert(token_transaction.recipient == receiver, 'Wrong recipient');

    // Verify transaction status is PROPOSED
    assert(transaction.tx_status == TransactionStatus::PROPOSED, 'Wrong transaction status');
}

#[test]
#[should_panic(expected: 'Caller is not a proposer')]
fn test_propose_token_transaction_not_proposer() {
    // Setup the test environment
    let mock_contract = deploy_mock_contract();
    let token = deploy_mock_token();
    let amount_to_send: u256 = 100000;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Setup access control - Deliberately NOT assigning proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);

    // Add member but don't assign proposer role
    mock_contract.add_member_pub(caller);

    // Verify caller doesn't have proposer role
    let has_proposer_role = mock_contract.is_proposer_pub(caller);
    assert(!has_proposer_role, 'Should not have proposer role');

    // Attempt to propose transaction without proposer role - should fail
    mock_contract.propose_token_transaction_pub(token.contract_address, amount_to_send, receiver);

    // This line should not be reached due to the panic
    stop_cheat_caller_address(mock_contract.contract_address);
}
