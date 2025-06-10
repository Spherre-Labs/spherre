use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait
};
use spherre::tests::mocks::mock_account_data::{
    IMockContractDispatcher, IMockContractDispatcherTrait
};

use spherre::types::{TransactionType, Permissions, TransactionStatus};
use starknet::{ContractAddress, contract_address_const};

fn proposer() -> ContractAddress {
    contract_address_const::<'proposer'>()
}

fn owner() -> ContractAddress {
    contract_address_const::<'owner'>()
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

#[test]
fn test_execute_member_add_transaction_successful() {
    let mock_contract = deploy_mock_contract();

    let caller: ContractAddress = owner();
    let new_member: ContractAddress = member_to_add();
    let permissions: u8 = 6; // VOTER and EXECUTOR
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
    // Propose Member Add Transaction
    let tx_id = mock_contract.propose_member_add_transaction_pub(new_member, permissions);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Checks
    // get transaction
    let transaction = mock_contract.get_transaction_pub(tx_id);
    // check that the transaction type is type TOKEN::SEND
    assert(transaction.tx_type == TransactionType::MEMBER_ADD, 'Invalid Transaction');
    let member_add_transaction = mock_contract.get_member_add_transaction_pub(tx_id);
    assert(member_add_transaction.member == new_member, 'Member is Invalid');
    assert(member_add_transaction.permissions == permissions, 'Invalid Permissions');

    // Approve Transaction
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.approve_transaction_pub(tx_id, caller);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Execute the transaction
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.execute_member_add_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Checks
    let transaction = mock_contract.get_transaction_pub(tx_id);
    // check that the transaction status is EXECUTED
    assert(transaction.tx_status == TransactionStatus::EXECUTED, 'Invalid Status');

    // check that new member is member
    assert(mock_contract.is_member_pub(new_member), 'New member should be a member');

    // check that the new member has the permissions
    assert(
        mock_contract.has_permission_pub(new_member, Permissions::VOTER),
        'Voter permission not found'
    );
    assert(
        mock_contract.has_permission_pub(new_member, Permissions::EXECUTOR),
        'Executor permission not found'
    );
}
