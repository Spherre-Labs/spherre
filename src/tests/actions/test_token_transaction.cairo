use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait
};
use spherre::interfaces::ierc20::{IERC20Dispatcher};
use spherre::tests::mocks::mock_account_data::{
    IMockContractDispatcher, IMockContractDispatcherTrait
};
use spherre::tests::mocks::mock_token::{IMockTokenDispatcher, IMockTokenDispatcherTrait};
use spherre::types::TransactionType;
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
    mock_contract.propose_token_transaction_pub(
        token.contract_address,
        amount_to_send,
        receiver
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
    mock_contract.propose_token_transaction_pub(
        token.contract_address,
        amount_to_send,
        receiver
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
    mock_contract.propose_token_transaction_pub(
        token.contract_address,
        amount_to_send,
        receiver
    ); // should panic
    stop_cheat_caller_address(mock_contract.contract_address);
}