use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use spherre::interfaces::ierc20::{IERC20Dispatcher};
use spherre::tests::mocks::mock_account_data::{
    IMockContractDispatcher, IMockContractDispatcherTrait,
};
use spherre::tests::mocks::mock_token::{IMockTokenDispatcher, IMockTokenDispatcherTrait};
use spherre::types::{Permissions, TransactionStatus, TransactionType};
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

fn proposer() -> ContractAddress {
    contract_address_const::<'proposer'>()
}

fn proposer_and_executor() -> ContractAddress {
    contract_address_const::<'proposer_and_executor'>()
}

fn member_to_remove() -> ContractAddress {
    contract_address_const::<'member_to_remove'>()
}

fn other_member() -> ContractAddress {
    contract_address_const::<'other_member'>()
}

fn zero_address() -> ContractAddress {
    contract_address_const::<0>()
}

#[test]
fn test_member_remove_proposal_successful() {
    let mock_contract = deploy_mock_contract();

    let caller: ContractAddress = proposer();
    let member: ContractAddress = member_to_remove();

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose member removal transaction
    let tx_id = mock_contract.propose_remove_member_transaction_pub(member);
    stop_cheat_caller_address(mock_contract.contract_address);

    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.tx_type == TransactionType::MEMBER_REMOVE, 'Invalid Transaction Type');

    let member_removal_transaction = mock_contract.get_member_removal_transaction_pub(tx_id);
    assert(member_removal_transaction.member_address == member, 'Member Address Invalid');
}

#[test]
fn test_get_member_removal_transaction_success() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let member = member_to_remove();

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    mock_contract.assign_proposer_permission_pub(caller);

    // Create a member removal transaction
    let tx_id = mock_contract.propose_remove_member_transaction_pub(member);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Test getting the member removal transaction
    let result = mock_contract.get_member_removal_transaction_pub(tx_id);
    assert(result.member_address == member, 'Wrong member address');
}


#[test]
#[should_panic(expected: ('Caller is not a member',))]
fn test_member_remove_proposal_not_member() {
    let mock_contract = deploy_mock_contract();

    let caller: ContractAddress = proposer();
    let member: ContractAddress = member_to_remove();

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose member removal transaction
    mock_contract.propose_remove_member_transaction_pub(member);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: ('Not member remove proposal',))]
fn test_get_member_removal_transaction_wrong_type() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let token = deploy_mock_token();
    let amount_to_mint: u256 = 10000000;
    let amount_to_send: u256 = 100000;
    let receiver: ContractAddress = other_member();

    let mock_token = IMockTokenDispatcher { contract_address: token.contract_address };
    mock_token.mint(mock_contract.contract_address, amount_to_mint);

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Create a different type of transaction (not MEMBER_REMOVE)
    let tx_id = mock_contract
        .propose_token_transaction_pub(token.contract_address, amount_to_send, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);

    // This should panic with MEMBER_NOT_FOUND error
    mock_contract.get_member_removal_transaction_pub(tx_id);
}


#[test]
#[should_panic(expected: ('Transaction is out of range',))]
fn test_get_member_removal_transaction_nonexistent_transaction() {
    let mock_contract = deploy_mock_contract();
    let nonexistent_id = 999_u256;

    // This should panic as the transaction doesn't exist
    mock_contract.get_member_removal_transaction_pub(nonexistent_id);
}

#[test]
fn test_member_removal_transaction_list_empty() {
    let mock_contract = deploy_mock_contract();

    let result = mock_contract.member_removal_transaction_list_pub();

    assert(result.len() == 0, 'List should be empty');
}

#[test]
fn test_member_removal_transaction_list_multiple_transactions() {
    let mock_contract = deploy_mock_contract();
    let caller = proposer();
    let member1 = member_to_remove();
    let member2 = other_member();
    let member3 = contract_address_const::<'third_member'>();

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member1);
    mock_contract.add_member_pub(member2);
    mock_contract.add_member_pub(member3);
    mock_contract.assign_proposer_permission_pub(caller);

    // Create multiple member removal transactions
    mock_contract.propose_remove_member_transaction_pub(member1);
    mock_contract.propose_remove_member_transaction_pub(member2);
    mock_contract.propose_remove_member_transaction_pub(member3);
    stop_cheat_caller_address(mock_contract.contract_address);

    let result = mock_contract.member_removal_transaction_list_pub();

    assert(result.len() == 3, 'Should have three transactions');
    assert(*result.at(0).member_address == member1, 'Wrong first member');
    assert(*result.at(1).member_address == member2, 'Wrong second member');
    assert(*result.at(2).member_address == member3, 'Wrong third member');
}

#[test]
#[should_panic(expected: ('Cannot remove last voter',))]
fn test_propose_remove_member_transaction_last_voter() {
    let mock_contract = deploy_mock_contract();

    let caller: ContractAddress = proposer_and_executor();
    let member: ContractAddress = member_to_remove();

    // Add the caller and member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    // Assign Proposer Role
    mock_contract.assign_proposer_permission_pub(caller);
    // Assign Voter Role to member
    mock_contract.assign_voter_permission_pub(member);
    // Assign Executor Role
    mock_contract.assign_executor_permission_pub(caller);
    // Set Threshold
    mock_contract.set_threshold_pub(1);

    // Propose Transaction
    mock_contract.propose_remove_member_transaction_pub(member);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: ('Cannot remove last proposer',))]
fn test_propose_remove_member_transaction_last_proposer() {
    let mock_contract = deploy_mock_contract();

    let caller: ContractAddress = proposer_and_executor();
    let member: ContractAddress = member_to_remove();

    // Add the caller and member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    // Assign Proposer Role
    mock_contract.assign_proposer_permission_pub(caller);
    // Assign Voter Role
    mock_contract.assign_voter_permission_pub(member);
    // Assign Executor Role
    mock_contract.assign_executor_permission_pub(caller);
    // Set Threshold
    mock_contract.set_threshold_pub(1);

    // Propose Transaction (should panic)
    mock_contract.propose_remove_member_transaction_pub(caller);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: ('Cannot remove last executor',))]
fn test_propose_remove_member_transaction_last_executor() {
    let mock_contract = deploy_mock_contract();

    let caller: ContractAddress = proposer_and_executor();
    let member: ContractAddress = member_to_remove();

    // Add the caller and member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    // Assign Proposer Role
    mock_contract.assign_proposer_permission_pub(caller);
    // Assign Voter Role
    mock_contract.assign_voter_permission_pub(caller);
    // Assign Executor Role
    mock_contract.assign_executor_permission_pub(member);
    // Set Threshold
    mock_contract.set_threshold_pub(1);

    // Propose Transaction (should panic)
    mock_contract.propose_remove_member_transaction_pub(member);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: ('lower threshold',))]
fn test_propose_remove_member_transaction_with_threshold_equal_to_number_of_voter() {
    let mock_contract = deploy_mock_contract();

    let caller: ContractAddress = proposer_and_executor();
    let member: ContractAddress = member_to_remove();

    // Add the caller and member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    // Assign Proposer Role
    mock_contract.assign_proposer_permission_pub(caller);
    // Assign Voter Role
    mock_contract.assign_voter_permission_pub(caller);
    // Assign Voter Role to member
    mock_contract.assign_voter_permission_pub(member);
    // Assign Executor Role
    mock_contract.assign_executor_permission_pub(caller);
    // Set Threshold
    mock_contract.set_threshold_pub(2);

    // Propose Transaction (should panic)
    mock_contract.propose_remove_member_transaction_pub(member);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
fn test_execute_remove_member_transaction_successful() {
    let mock_contract = deploy_mock_contract();

    let caller: ContractAddress = proposer_and_executor();
    let member: ContractAddress = member_to_remove();

    //
    // propose transaction functionality
    //
    // add member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.add_member_pub(member);
    // Assign Proposer Role
    mock_contract.assign_proposer_permission_pub(caller);
    // Assign Voter Role
    mock_contract.assign_voter_permission_pub(caller);
    // Assign Executor Role
    mock_contract.assign_executor_permission_pub(caller);
    // Assign Proposer Role to member
    mock_contract.assign_proposer_permission_pub(member);
    // Assign Voter Role to member
    mock_contract.assign_voter_permission_pub(member);
    // Assign Executor Role to member
    mock_contract.assign_executor_permission_pub(member);
    // Set Threshold
    mock_contract.set_threshold_pub(1);
    // Propose Transaction
    let tx_id = mock_contract.propose_remove_member_transaction_pub(member);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Checks
    // get transaction
    let transaction = mock_contract.get_transaction_pub(tx_id);
    // check that the transaction type is type TOKEN::SEND
    assert(transaction.tx_type == TransactionType::MEMBER_REMOVE, 'Invalid Transaction');
    let member_removal_transaction = mock_contract.get_member_removal_transaction_pub(tx_id);
    assert(member_removal_transaction.member_address == member, 'Member is Invalid');

    // Approve Transaction
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.approve_transaction_pub(tx_id, caller);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Execute the transaction
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.execute_remove_member_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Checks
    let transaction = mock_contract.get_transaction_pub(tx_id);
    // check that the transaction status is EXECUTED
    assert(transaction.tx_status == TransactionStatus::EXECUTED, 'Invalid Status');

    // Check that the member has been removed
    assert(!mock_contract.is_member_pub(member), 'Member should have been removed');
    // Check that member does not have permissions
    assert!(
        !mock_contract.has_permission_pub(member, Permissions::PROPOSER),
        "Member should not have proposer permission",
    );
    assert!(
        !mock_contract.has_permission_pub(member, Permissions::VOTER),
        "Member should not have voter permission",
    );
    assert!(
        !mock_contract.has_permission_pub(member, Permissions::EXECUTOR),
        "Member should not have executor permission",
    );
}

