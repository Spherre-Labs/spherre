use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use spherre::tests::mocks::mock_account_data::{
    IMockContractDispatcher, IMockContractDispatcherTrait,
};
use spherre::types::{Permissions, TransactionStatus, TransactionType};
use starknet::{ContractAddress, contract_address_const};

fn deploy_mock_contract() -> IMockContractDispatcher {
    let contract_class = declare("MockContract").unwrap().contract_class();
    let mut calldata = array![];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IMockContractDispatcher { contract_address }
}

fn proposer() -> ContractAddress {
    contract_address_const::<'proposer'>()
}

fn member_to_edit() -> ContractAddress {
    contract_address_const::<'member_to_edit'>()
}

#[test]
fn test_propose_member_permission_transaction_successful() {
    let mock_contract = deploy_mock_contract();

    let caller: ContractAddress = proposer();
    let member: ContractAddress = member_to_edit();
    let new_permissions: u8 = 6; // VOTER and EXECUTOR permissions

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose member permission transaction
    let tx_id = mock_contract.propose_edit_permission_transaction_pub(member, new_permissions);
    stop_cheat_caller_address(mock_contract.contract_address);

    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(
        transaction.tx_type == TransactionType::MEMBER_PERMISSION_EDIT, 'Invalid Transaction Type',
    );

    let perm_transaction = mock_contract.get_edit_permission_transaction_pub(tx_id);
    assert(perm_transaction.member == member, 'Member Address Invalid');
    assert(perm_transaction.new_permissions == new_permissions, 'Permissions Invalid');
}

#[test]
#[should_panic(expected: 'Member address is zero')]
fn test_propose_member_permission_transaction_fail_with_zero_member() {
    let mock_contract = deploy_mock_contract();

    let caller: ContractAddress = proposer();
    let member: ContractAddress = 0.try_into().unwrap(); // Zero Address
    let new_permissions: u8 = 6;

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose member permission transaction - should panic
    mock_contract.propose_edit_permission_transaction_pub(member, new_permissions);
}

#[test]
#[should_panic(expected: 'Permission mask is invalid')]
fn test_propose_member_permission_transaction_fail_with_invalid_permission() {
    let mock_contract = deploy_mock_contract();

    let caller: ContractAddress = proposer();
    let member: ContractAddress = member_to_edit();
    let invalid_permissions: u8 = 8; // Invalid permission mask

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose member permission transaction - should panic
    mock_contract.propose_edit_permission_transaction_pub(member, invalid_permissions);
}

#[test]
#[should_panic(expected: 'Member does not exist')]
fn test_propose_member_permission_transaction_fail_with_non_member() {
    let mock_contract = deploy_mock_contract();

    let caller: ContractAddress = proposer();
    let non_member: ContractAddress = member_to_edit();
    let new_permissions: u8 = 6;

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose member permission transaction - should panic
    mock_contract.propose_edit_permission_transaction_pub(non_member, new_permissions);
}

#[test]
#[should_panic(expected: 'Permission unchanged')]
fn test_propose_member_permission_transaction_fail_with_same_permissions() {
    let mock_contract = deploy_mock_contract();

    let caller: ContractAddress = proposer();
    let member: ContractAddress = member_to_edit();
    let initial_permissions: u8 = 6; // VOTER and EXECUTOR permissions

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(member);
    mock_contract.assign_executor_permission_pub(member);

    // Propose member permission transaction with same permissions - should panic
    mock_contract.propose_edit_permission_transaction_pub(member, initial_permissions);
}

#[test]
#[should_panic(expected: 'Transaction is out of range')]
fn test_get_member_permission_transaction_nonexistent() {
    let mock_contract = deploy_mock_contract();
    let nonexistent_id = 999_u256;

    // This should panic as the transaction doesn't exist
    mock_contract.get_edit_permission_transaction_pub(nonexistent_id);
}

#[test]
fn test_get_member_permission_transaction_success() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let member = member_to_edit();
    let new_permissions: u8 = 6;

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    mock_contract.assign_proposer_permission_pub(caller);

    // Create a member permission transaction
    let tx_id = mock_contract.propose_edit_permission_transaction_pub(member, new_permissions);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Test getting the member permission transaction
    let permission_transaction = mock_contract.get_edit_permission_transaction_pub(tx_id);
    assert(permission_transaction.member == member, 'Wrong member address');
    assert(permission_transaction.new_permissions == new_permissions, 'Wrong permissions');
}


#[test]
fn test_execute_member_permission_transaction_success() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let member = member_to_edit();
    let new_permissions: u8 = 6;

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(caller);
    mock_contract.assign_executor_permission_pub(caller);
    // Assign member permissions
    mock_contract.assign_proposer_permission_pub(member);
    mock_contract.assign_voter_permission_pub(member);
    mock_contract.assign_executor_permission_pub(member);

    // check whether member has permissions
    assert(
        mock_contract.has_permission_pub(member, Permissions::PROPOSER),
        'should have proposer permission',
    );
    assert(
        mock_contract.has_permission_pub(member, Permissions::VOTER),
        'should have voter permission',
    );
    assert(
        mock_contract.has_permission_pub(member, Permissions::EXECUTOR),
        'should have executor permission',
    );

    // Create a member permission transaction
    let tx_id = mock_contract.propose_edit_permission_transaction_pub(member, new_permissions);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Test getting the member permission transaction
    let permission_transaction = mock_contract.get_edit_permission_transaction_pub(tx_id);
    assert(permission_transaction.member == member, 'Wrong member address');
    assert(permission_transaction.new_permissions == new_permissions, 'Wrong permissions');

    // Approve the transaction
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.approve_transaction_pub(tx_id, caller);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Execute the transaction
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.execute_edit_permission_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Checks
    let transaction = mock_contract.get_transaction_pub(tx_id);
    // check that the transaction status is EXECUTED
    assert(transaction.tx_status == TransactionStatus::EXECUTED, 'Invalid Status');

    assert(
        !mock_contract.has_permission_pub(member, Permissions::PROPOSER),
        'proposer permission found',
    );
    assert(
        mock_contract.has_permission_pub(member, Permissions::VOTER),
        'should have voter permission',
    );
    assert(
        mock_contract.has_permission_pub(member, Permissions::EXECUTOR),
        'should have executor permission',
    );
}
