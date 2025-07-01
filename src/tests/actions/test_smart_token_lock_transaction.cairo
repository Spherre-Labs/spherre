use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait
};
use spherre::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use spherre::tests::mocks::mock_account_data::{
    IMockContractDispatcher, IMockContractDispatcherTrait
};
use spherre::tests::mocks::mock_token::{IMockTokenDispatcher, IMockTokenDispatcherTrait};
use spherre::types::{TransactionType, TransactionStatus};
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
    assert(smart_token_lock_transaction.token == token.contract_address, 'Contract Address Invalid');
    assert(smart_token_lock_transaction.amount == amount_to_send, 'Amount is Invalid');
    assert(smart_token_lock_transaction.duration == duration, 'Recipient is Invalid');
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
    let tx_id = mock_contract
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
    let tx_id = mock_contract
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
    let tx_id = mock_contract
        .propose_smart_token_lock_transaction_pub(token.contract_address, amount_to_send, duration);
    stop_cheat_caller_address(mock_contract_address);
}