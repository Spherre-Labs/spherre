use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait
};
use spherre::tests::mocks::mock_account_data::{
    IMockContractDispatcher, IMockContractDispatcherTrait
};

use spherre::types::{TransactionType, MemberAddData};
use starknet::{ContractAddress, contract_address_const};

fn proposer() -> ContractAddress {
    contract_address_const::<'proposer'>()
}

fn member_to_add() -> ContractAddress {
    contract_address_const::<'member_to_add'>()
}

fn deploy_mock_contract() -> IMockContractDispatcher {
    let contract_class = declare("MockContract").unwrap().contract_class();
    let mut calldata = array![];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IMockContractDispatcher { contract_address }
}

#[test]
fn test_propose_member_add_transaction_successful() {
    let mock_contract = deploy_mock_contract();

    let caller: ContractAddress = proposer();
    let member: ContractAddress = member_to_add();
    let permissions: u8 = 6; // VOTER and EXECUTOR

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose member add transaction
    let tx_id = mock_contract.propose_member_add_transaction_pub(member, permissions);
    stop_cheat_caller_address(mock_contract.contract_address);

    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.tx_type == TransactionType::MEMBER_ADD, 'Invalid Transaction Type');

    let member_removal_transaction = mock_contract.get_member_add_transaction_pub(tx_id);
    assert(member_removal_transaction.member == member, 'Member Address Invalid');
    assert(member_removal_transaction.permissions == permissions, 'Pemrissions Invalid');
}

#[test]
#[should_panic(expected: 'Permission mask is invalid')]
fn test_propose_member_add_transaction_fail_with_invalid_permission() {
    let mock_contract = deploy_mock_contract();

    let caller: ContractAddress = proposer();
    let member: ContractAddress = member_to_add();
    let permission: u8 = 8; // Invalid Permission mask

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose member add transaction
    // should panic
    mock_contract.propose_member_add_transaction_pub(member, permission);
}

#[test]
#[should_panic(expected: 'Member address is zero')]
fn test_propose_member_add_transaction_fail_with_zero_member() {
    let mock_contract = deploy_mock_contract();

    let caller: ContractAddress = proposer();
    let member: ContractAddress = 0.try_into().unwrap(); // Zero Address
    let permission: u8 = 6;

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose member add transaction
    // should panic
    mock_contract.propose_member_add_transaction_pub(member, permission);
}

#[test]
#[should_panic(expected: 'Address is already a member')]
fn test_propose_member_add_transaction_fail_with_adding_account_member() {
    let mock_contract = deploy_mock_contract();

    let caller: ContractAddress = proposer();
    let member: ContractAddress = member_to_add(); // Zero Address
    let permission: u8 = 6;

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member); // add account member
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose member add transaction
    // should panic
    mock_contract.propose_member_add_transaction_pub(member, permission);
}
