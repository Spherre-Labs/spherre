use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use spherre::interfaces::ierc20::{IERC20Dispatcher};
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
fn executor() -> ContractAddress {
    contract_address_const::<'executor'>()
}
fn setup_approved_smart_lock_transaction() -> (IMockContractDispatcher, IERC20Dispatcher, u256) {
    let mock_contract = deploy_mock_contract();
    let mock_contract_address = mock_contract.contract_address;
    let token = deploy_mock_token();
    let amount_to_mint: u256 = 10000000;
    let amount_to_lock: u256 = 100000;
    let duration: u64 = 86400; // 24 hours
    let owner_addr = owner();
    let executor_addr = executor();

    // Mint tokens to contract
    let mock_token = IMockTokenDispatcher { contract_address: token.contract_address };
    mock_token.mint(mock_contract_address, amount_to_mint);

    // members and permissions
    start_cheat_caller_address(mock_contract_address, owner_addr);
    mock_contract.add_member_pub(owner_addr);
    mock_contract.add_member_pub(executor_addr);
    mock_contract.assign_proposer_permission_pub(owner_addr);
    mock_contract.assign_voter_permission_pub(owner_addr);
    mock_contract.assign_executor_permission_pub(executor_addr);

    // threshold to 1 for easier testing
    mock_contract.set_threshold_pub(1);

    // Propose smart token lock transaction
    let tx_id = mock_contract
        .propose_smart_token_lock_transaction_pub(token.contract_address, amount_to_lock, duration);

    // Approve the transaction
    mock_contract.approve_transaction_pub(tx_id, owner_addr);
    stop_cheat_caller_address(mock_contract_address);

    (mock_contract, token, tx_id)
}

#[test]
fn test_propose_smart_token_lock() {
    let mock_contract = deploy_mock_contract();
    let mock_contract_address = mock_contract.contract_address;
    let token = deploy_mock_token();
    let amount_to_mint: u256 = 10000000;
    let amount_to_send: u256 = 100000;
    let caller: ContractAddress = owner();
    let duration: u64 = 86400;
    // Mint token for account
    let mock_token = IMockTokenDispatcher { contract_address: token.contract_address };
    mock_token.mint(mock_contract_address, amount_to_mint);

    start_cheat_caller_address(mock_contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    let tx_id = mock_contract
        .propose_smart_token_lock_transaction_pub(token.contract_address, amount_to_send, duration);
    stop_cheat_caller_address(mock_contract_address);

    // Checks
    // get transaction
    let transaction = mock_contract.get_transaction_pub(tx_id);
    // check that the transaction type is type TOKEN::SEND
    assert(transaction.tx_type == TransactionType::SMART_TOKEN_LOCK, 'Invalid Transaction');
    let smart_token_lock_transaction = mock_contract.get_smart_token_lock_transaction_pub(tx_id);
    assert(
        smart_token_lock_transaction.token == token.contract_address, 'Contract Address Invalid',
    );
    assert(smart_token_lock_transaction.amount == amount_to_send, 'Amount is Invalid');
    assert(smart_token_lock_transaction.duration == duration, 'Duration is Invalid');
}

#[test]
#[should_panic(expected: 'Invalid Token Lock Duration')]
fn test_zero_duration_should_fail() {
    let mock_contract = deploy_mock_contract();
    let mock_contract_address = mock_contract.contract_address;
    let token = deploy_mock_token();
    let amount_to_mint: u256 = 10000000;
    let amount_to_send: u256 = 100000;
    let caller: ContractAddress = owner();
    let duration: u64 = 0;
    // Mint token for account
    let mock_token = IMockTokenDispatcher { contract_address: token.contract_address };
    mock_token.mint(mock_contract_address, amount_to_mint);

    start_cheat_caller_address(mock_contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract
        .propose_smart_token_lock_transaction_pub(token.contract_address, amount_to_send, duration);
    stop_cheat_caller_address(mock_contract_address);
}

#[test]
#[should_panic(expected: 'Amount is invalid')]
fn test_zero_amount_should_fail() {
    let mock_contract = deploy_mock_contract();
    let mock_contract_address = mock_contract.contract_address;
    let token = deploy_mock_token();
    let amount_to_mint: u256 = 10000000;
    let amount_to_send: u256 = 0;
    let caller: ContractAddress = owner();
    let duration: u64 = 86400;
    // Mint token for account
    let mock_token = IMockTokenDispatcher { contract_address: token.contract_address };
    mock_token.mint(mock_contract_address, amount_to_mint);

    start_cheat_caller_address(mock_contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract
        .propose_smart_token_lock_transaction_pub(token.contract_address, amount_to_send, duration);
    stop_cheat_caller_address(mock_contract_address);
}

#[test]
#[should_panic(expected: 'Insufficient token amount')]
fn test_insufficient_token_balance_should_fail() {
    let mock_contract = deploy_mock_contract();
    let mock_contract_address = mock_contract.contract_address;
    let token = deploy_mock_token();
    let amount_to_mint: u256 = 0;
    let amount_to_send: u256 = 100000;
    let caller: ContractAddress = owner();
    let duration: u64 = 86400;
    // Mint token for account
    let mock_token = IMockTokenDispatcher { contract_address: token.contract_address };
    mock_token.mint(mock_contract_address, amount_to_mint);

    start_cheat_caller_address(mock_contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract
        .propose_smart_token_lock_transaction_pub(token.contract_address, amount_to_send, duration);
    stop_cheat_caller_address(mock_contract_address);
}

#[test]
fn test_execute_smart_token_lock_transaction_success() {
    let (mock_contract, token, tx_id) = setup_approved_smart_lock_transaction();
    let mock_contract_address = mock_contract.contract_address;
    let executor_addr = executor();
    let amount_to_lock: u256 = 100000;
    let duration: u64 = 86400;

    // Verify transaction is approved before execution
    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.tx_status == TransactionStatus::APPROVED, 'Transaction not approved');

    // Execute the smart token lock transaction
    start_cheat_caller_address(mock_contract_address, executor_addr);
    let lock_id = mock_contract.execute_smart_token_lock_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract_address);

    // Verify transaction status changed to executed
    let executed_transaction = mock_contract.get_transaction_pub(tx_id);
    assert(
        executed_transaction.tx_status == TransactionStatus::EXECUTED, 'Transaction not executed',
    );

    // Verify lock_id was returned (should be non-zero)
    assert(lock_id > 0, 'Invalid lock ID returned');

    // Verify smart token lock transaction details are preserved
    let smart_lock_tx = mock_contract.get_smart_token_lock_transaction_pub(tx_id);
    assert(smart_lock_tx.token == token.contract_address, 'Token address mismatch');
    assert(smart_lock_tx.amount == amount_to_lock, 'Amount mismatch');
    assert(smart_lock_tx.duration == duration, 'Duration mismatch');
}

#[test]
#[should_panic(expected: 'Transaction is not executable')]
fn test_execute_smart_token_lock_transaction_not_approved() {
    let mock_contract = deploy_mock_contract();
    let mock_contract_address = mock_contract.contract_address;
    let token = deploy_mock_token();
    let amount_to_mint: u256 = 10000000;
    let amount_to_lock: u256 = 100000;
    let duration: u64 = 86400;
    let owner_addr = owner();
    let executor_addr = executor();

    // Mint tokens and setup
    let mock_token = IMockTokenDispatcher { contract_address: token.contract_address };
    mock_token.mint(mock_contract_address, amount_to_mint);

    start_cheat_caller_address(mock_contract_address, owner_addr);
    mock_contract.add_member_pub(owner_addr);
    mock_contract.add_member_pub(executor_addr);
    mock_contract.assign_proposer_permission_pub(owner_addr);
    mock_contract.assign_executor_permission_pub(executor_addr);

    // Propose but don't approve
    let tx_id = mock_contract
        .propose_smart_token_lock_transaction_pub(token.contract_address, amount_to_lock, duration);
    stop_cheat_caller_address(mock_contract_address);

    // Try to execute unapproved transaction
    start_cheat_caller_address(mock_contract_address, executor_addr);
    mock_contract.execute_smart_token_lock_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract_address);
}

#[test]
#[should_panic(expected: 'Invalid Token Lock Transaction')]
fn test_execute_smart_token_lock_transaction_wrong_type() {
    let mock_contract = deploy_mock_contract();
    let mock_contract_address = mock_contract.contract_address;
    let token = deploy_mock_token();
    let owner_addr = owner();
    let executor_addr = executor();

    // Mint sufficient tokens
    let amount_to_mint: u256 = 10000000;
    let mock_token = IMockTokenDispatcher { contract_address: token.contract_address };
    mock_token.mint(mock_contract_address, amount_to_mint);

    // Setup members and permissions
    start_cheat_caller_address(mock_contract_address, owner_addr);
    mock_contract.add_member_pub(owner_addr);
    mock_contract.add_member_pub(executor_addr);
    mock_contract.assign_proposer_permission_pub(owner_addr);
    mock_contract.assign_voter_permission_pub(owner_addr);
    mock_contract.assign_executor_permission_pub(executor_addr);
    mock_contract.set_threshold_pub(1);

    // Created a different type of transaction (token transaction instead of smart lock)
    let tx_id = mock_contract
        .propose_token_transaction_pub(
            token.contract_address, 1000, contract_address_const::<'recipient'>(),
        );

    // Approve the transaction
    mock_contract.approve_transaction_pub(tx_id, owner_addr);
    stop_cheat_caller_address(mock_contract_address);

    // Try to execute as smart token lock transaction (should fail)
    start_cheat_caller_address(mock_contract_address, executor_addr);
    mock_contract.execute_smart_token_lock_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract_address);
}

#[test]
#[should_panic(expected: 'Insufficient token amount')]
fn test_execute_smart_token_lock_transaction_insufficient_balance() {
    let mock_contract = deploy_mock_contract();
    let mock_contract_address = mock_contract.contract_address;
    let token = deploy_mock_token();
    let amount_to_mint: u256 = 50000; // Less than amount to lock
    let amount_to_lock: u256 = 100000; // More than minted amount
    let duration: u64 = 86400;
    let owner_addr = owner();
    let executor_addr = executor();

    // Mint insufficient tokens
    let mock_token = IMockTokenDispatcher { contract_address: token.contract_address };
    mock_token.mint(mock_contract_address, amount_to_mint);

    start_cheat_caller_address(mock_contract_address, owner_addr);
    mock_contract.add_member_pub(owner_addr);
    mock_contract.add_member_pub(executor_addr);
    mock_contract.assign_proposer_permission_pub(owner_addr);
    mock_contract.assign_voter_permission_pub(owner_addr);
    mock_contract.assign_executor_permission_pub(executor_addr);
    mock_contract.set_threshold_pub(1);

    // Propose smart token lock transaction
    let tx_id = mock_contract
        .propose_smart_token_lock_transaction_pub(token.contract_address, amount_to_lock, duration);

    // Approve the transaction
    mock_contract.approve_transaction_pub(tx_id, owner_addr);
    stop_cheat_caller_address(mock_contract_address);

    // Try to execute with insufficient balance (should fail)
    start_cheat_caller_address(mock_contract_address, executor_addr);
    mock_contract.execute_smart_token_lock_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract_address);
}

#[test]
#[should_panic(expected: 'Transaction is not executable')]
fn test_execute_smart_token_lock_transaction_already_executed() {
    let (mock_contract, _, tx_id) = setup_approved_smart_lock_transaction();
    let mock_contract_address = mock_contract.contract_address;
    let executor_addr = executor();

    // Execute the transaction once
    start_cheat_caller_address(mock_contract_address, executor_addr);
    mock_contract.execute_smart_token_lock_transaction_pub(tx_id);

    // Try to execute again (should fail)
    mock_contract.execute_smart_token_lock_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract_address);
}


#[test]
#[should_panic(expected: 'Pausable: paused')]
fn test_execute_smart_token_lock_transaction_when_paused() {
    let (mock_contract, _, tx_id) = setup_approved_smart_lock_transaction();
    let mock_contract_address = mock_contract.contract_address;
    let owner_addr = owner();
    let executor_addr = executor();

    // Pause the contract
    start_cheat_caller_address(mock_contract_address, owner_addr);
    mock_contract.pause();
    stop_cheat_caller_address(mock_contract_address);

    // Try to execute when paused (should fail due to pause guard)
    start_cheat_caller_address(mock_contract_address, executor_addr);
    mock_contract.execute_smart_token_lock_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract_address);
}

#[test]
fn test_execute_smart_token_lock_transaction_integration_flow() {
    // integration flow = propose > approve > execute
    let mock_contract = deploy_mock_contract();
    let mock_contract_address = mock_contract.contract_address;
    let token = deploy_mock_token();
    let amount_to_mint: u256 = 10000000;
    let amount_to_lock: u256 = 100000;
    let duration: u64 = 86400;
    let owner_addr = owner();
    let executor_addr = executor();

    // Setup
    let mock_token = IMockTokenDispatcher { contract_address: token.contract_address };
    mock_token.mint(mock_contract_address, amount_to_mint);

    start_cheat_caller_address(mock_contract_address, owner_addr);
    mock_contract.add_member_pub(owner_addr);
    mock_contract.add_member_pub(executor_addr);
    mock_contract.assign_proposer_permission_pub(owner_addr);
    mock_contract.assign_voter_permission_pub(owner_addr);
    mock_contract.assign_executor_permission_pub(executor_addr);
    mock_contract.set_threshold_pub(1);

    // Propose
    let tx_id = mock_contract
        .propose_smart_token_lock_transaction_pub(token.contract_address, amount_to_lock, duration);

    // Verify proposal
    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.tx_type == TransactionType::SMART_TOKEN_LOCK, 'Wrong transaction type');
    // assert(transaction.tx_status == TransactionStatus::PENDING, 'Should be pending');

    // Approve
    mock_contract.approve_transaction_pub(tx_id, owner_addr);

    // Verify approval
    let approved_transaction = mock_contract.get_transaction_pub(tx_id);
    assert(approved_transaction.tx_status == TransactionStatus::APPROVED, 'Should be approved');
    stop_cheat_caller_address(mock_contract_address);

    // Execute
    start_cheat_caller_address(mock_contract_address, executor_addr);
    let lock_id = mock_contract.execute_smart_token_lock_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract_address);

    // Verify execution
    let executed_transaction = mock_contract.get_transaction_pub(tx_id);
    assert(executed_transaction.tx_status == TransactionStatus::EXECUTED, 'Should be executed');
    assert(lock_id > 0, 'Should return valid lock ID');

    // Verify smart lock transaction details remain intact
    let smart_lock_tx = mock_contract.get_smart_token_lock_transaction_pub(tx_id);
    assert(smart_lock_tx.token == token.contract_address, 'Token should match');
    assert(smart_lock_tx.amount == amount_to_lock, 'Amount should match');
    assert(smart_lock_tx.duration == duration, 'Duration should match');
    assert(smart_lock_tx.transaction_id == tx_id, 'Transaction ID should match');
}
