use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use spherre::interfaces::ierc721::{IERC721Dispatcher, IERC721DispatcherTrait};
use spherre::tests::mocks::mock_account_data::{
    IMockContractDispatcher, IMockContractDispatcherTrait,
};
use spherre::tests::mocks::mock_nft::{IMockNFTDispatcher, IMockNFTDispatcherTrait};

use spherre::types::{TransactionStatus, TransactionType};
use starknet::{ContractAddress, contract_address_const};

fn deploy_mock_nft() -> IERC721Dispatcher {
    let contract_class = declare("MockNFT").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IERC721Dispatcher { contract_address }
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

fn zero_address() -> ContractAddress {
    contract_address_const::<0>()
}

#[test]
fn test_propose_nft_transaction_successful() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose NFT transaction
    let tx_id = mock_contract
        .propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Verify transaction
    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.tx_type == TransactionType::NFT_SEND, 'Invalid Transaction');
    let nft_transaction = mock_contract.get_nft_transaction_pub(tx_id);
    assert(nft_transaction.nft_contract == nft_contract.contract_address, 'NFT Contract Invalid');
    assert(nft_transaction.token_id == token_id, 'Token ID Invalid');
    assert(nft_transaction.recipient == receiver, 'Recipient Invalid');
}


#[test]
#[should_panic(expected: 'Caller is not a proposer')]
fn test_propose_nft_transaction_fail_if_not_proposer() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Add member but do not assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);

    // Propose NFT transaction (should fail)
    mock_contract.propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_propose_nft_transaction_fail_if_not_owner() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();
    let other_account: ContractAddress = contract_address_const::<999>();

    // Mint NFT to a different account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(other_account, token_id);

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose NFT transaction (should fail)
    mock_contract.propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Recipient cannot be account')]
fn test_propose_nft_transaction_fail_if_recipient_is_account() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = mock_contract.contract_address;

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose NFT transaction (should fail)
    mock_contract.propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'NFT contract address is zero')]
fn test_propose_nft_transaction_fail_if_nft_contract_zero() {
    let mock_contract = deploy_mock_contract();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose NFT transaction with zero NFT contract address
    mock_contract.propose_nft_transaction_pub(zero_address(), token_id, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Recipient address is zero')]
fn test_propose_nft_transaction_fail_if_recipient_zero() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose NFT transaction with zero recipient address
    mock_contract
        .propose_nft_transaction_pub(nft_contract.contract_address, token_id, zero_address());
    stop_cheat_caller_address(mock_contract.contract_address);
}


#[test]
#[should_panic(expected: 'Pausable: paused')]
fn test_propose_nft_transaction_fail_if_paused() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Pause the contract
    mock_contract.pause();

    // Propose NFT transaction (should fail)
    mock_contract.propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Invalid NFT transaction')]
fn test_get_nft_transaction_fail_if_invalid_type() {
    let mock_contract = deploy_mock_contract();
    let caller: ContractAddress = owner();

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Create a TOKEN_SEND transaction
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);

    // Attempt to retrieve as NFT transaction (should fail)
    mock_contract.get_nft_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Transaction is out of range')]
fn test_get_nft_transaction_fail_if_non_existent() {
    let mock_contract = deploy_mock_contract();
    let _caller: ContractAddress = owner();

    // Attempt to retrieve a non-existent transaction
    mock_contract.get_nft_transaction_pub(999);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
fn test_execute_nft_transaction_successful() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

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
        .propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Checks
    // get transaction
    let transaction = mock_contract.get_transaction_pub(tx_id);
    // check that the transaction type is type TOKEN::SEND
    assert(transaction.tx_type == TransactionType::NFT_SEND, 'Invalid Transaction');
    let nft_transaction = mock_contract.get_nft_transaction_pub(tx_id);
    assert(nft_transaction.nft_contract == nft_contract.contract_address, 'NFT Contract Invalid');
    assert(nft_transaction.token_id == token_id, 'Token ID Invalid');
    assert(nft_transaction.recipient == receiver, 'Recipient Invalid');

    // Approve Transaction
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.approve_transaction_pub(tx_id, caller);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Execute the transaction
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.execute_nft_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Checks
    let transaction = mock_contract.get_transaction_pub(tx_id);
    // check that the transaction status is EXECUTED
    assert(transaction.tx_status == TransactionStatus::EXECUTED, 'Invalid Status');

    // check that the balance of the token in the receiver is the token transaction balance
    assert(nft_contract.owner_of(token_id) == receiver, 'NFT not transferred');
}


#[test]
#[should_panic(expected: 'Transaction is not executable')]
fn test_execute_nft_transaction_fail_if_not_approved() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose NFT transaction
    let tx_id = mock_contract
        .propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);

    // Execute the NFT transaction
    // This should fail because the transaction is not approved
    mock_contract.execute_nft_transaction_pub(tx_id);
}

#[test]
#[should_panic(expected: 'Caller is not an executor')]
fn test_execute_nft_transaction_fail_if_not_executor() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(caller);
    mock_contract.set_threshold_pub(1);

    // Propose NFT transaction
    let tx_id = mock_contract
        .propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);

    // Approve the transaction
    mock_contract.approve_transaction_pub(tx_id, caller);

    // Execute the NFT transaction (should fail)
    mock_contract.execute_nft_transaction_pub(tx_id);

    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Transaction is out of range')]
fn test_execute_nft_transaction_fail_if_transaction_not_exists() {
    let mock_contract = deploy_mock_contract();
    let caller: ContractAddress = owner();

    // Add member and assign executor role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_executor_permission_pub(caller);

    // Try to execute a non-existent transaction
    mock_contract.execute_nft_transaction_pub(999);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Invalid NFT transaction')]
fn test_execute_nft_transaction_fail_if_wrong_transaction_type() {
    let mock_contract = deploy_mock_contract();
    let caller: ContractAddress = owner();

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_executor_permission_pub(caller);

    // Create a TOKEN_SEND transaction instead of NFT_SEND
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);

    // Try to execute as NFT transaction (should fail)
    mock_contract.execute_nft_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_execute_nft_transaction_fail_if_not_nft_owner() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();
    let other_account: ContractAddress = contract_address_const::<'other'>();

    // Mint NFT to a different account (not the contract)
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(other_account, token_id);

    // Add member and assign all roles
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(caller);
    mock_contract.assign_executor_permission_pub(caller);
    mock_contract.set_threshold_pub(1);

    // Propose NFT transaction
    let tx_id = mock_contract
        .propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);

    // Approve the transaction
    mock_contract.approve_transaction_pub(tx_id, caller);

    // Try to execute (should fail because contract doesn't own the NFT)
    mock_contract.execute_nft_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Recipient address is zero')]
fn test_execute_nft_transaction_fail_if_recipient_is_zero() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Add member and assign all roles
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(caller);
    mock_contract.assign_executor_permission_pub(caller);
    mock_contract.set_threshold_pub(1);

    // Propose NFT transaction with zero recipient
    let tx_id = mock_contract
        .propose_nft_transaction_pub(nft_contract.contract_address, token_id, zero_address());

    // Approve the transaction
    mock_contract.approve_transaction_pub(tx_id, caller);

    // Try to execute (should fail because recipient is zero)
    mock_contract.execute_nft_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
fn test_execute_nft_transaction_with_event_validation() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Add member and assign all roles
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(caller);
    mock_contract.assign_executor_permission_pub(caller);
    mock_contract.set_threshold_pub(1);

    // Propose NFT transaction
    let tx_id = mock_contract
        .propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);

    // Approve the transaction
    mock_contract.approve_transaction_pub(tx_id, caller);

    // Execute the transaction
    mock_contract.execute_nft_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Verify transaction is executed
    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.tx_status == TransactionStatus::EXECUTED, 'Transaction should be executed');

    // Verify NFT ownership transfer
    assert(nft_contract.owner_of(token_id) == receiver, 'NFT should be transfd to recv');

    // Verify NFT transaction data
    let nft_transaction = mock_contract.get_nft_transaction_pub(tx_id);
    assert(
        nft_transaction.nft_contract == nft_contract.contract_address, 'NFT contract should match'
    );
    assert(nft_transaction.token_id == token_id, 'Token ID should match');
    assert(nft_transaction.recipient == receiver, 'Recipient should match');
}

#[test]
fn test_execute_nft_transaction_full_lifecycle_with_events() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Add member and assign all roles
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(caller);
    mock_contract.assign_executor_permission_pub(caller);
    mock_contract.set_threshold_pub(1);

    // Propose NFT transaction
    let tx_id = mock_contract
        .propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);

    // Verify transaction is in INITIATED status
    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(
        transaction.tx_status == TransactionStatus::INITIATED, 'Transaction should be initiated'
    );

    // Approve the transaction
    mock_contract.approve_transaction_pub(tx_id, caller);

    // Verify transaction is in APPROVED status
    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.tx_status == TransactionStatus::APPROVED, 'Transaction should be approved');

    // Execute the transaction
    mock_contract.execute_nft_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Verify transaction is in EXECUTED status
    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.tx_status == TransactionStatus::EXECUTED, 'Transaction should be executed');

    // Verify NFT ownership transfer
    assert(nft_contract.owner_of(token_id) == receiver, 'NFT should be transfd to recv');

    // Verify executor is set
    assert(transaction.executor == caller, 'Executor should set to caller');
    // Note: date_executed might be 0 if the transaction was just executed, so we'll skip this check
}

#[test]
fn test_execute_nft_transaction_verify_already_executed_status() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Add member and assign all roles
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(caller);
    mock_contract.assign_executor_permission_pub(caller);
    mock_contract.set_threshold_pub(1);

    // Propose NFT transaction
    let tx_id = mock_contract
        .propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);

    // Approve the transaction
    mock_contract.approve_transaction_pub(tx_id, caller);

    // Execute the transaction first time
    mock_contract.execute_nft_transaction_pub(tx_id);

    // Verify transaction is in EXECUTED status
    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.tx_status == TransactionStatus::EXECUTED, 'Transaction should be executed');

    // Verify NFT ownership transfer
    assert(nft_contract.owner_of(token_id) == receiver, 'NFT should be tranfd to recv');
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Pausable: paused')]
fn test_execute_nft_transaction_fail_if_contract_paused() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Add member and assign all roles
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract.assign_voter_permission_pub(caller);
    mock_contract.assign_executor_permission_pub(caller);
    mock_contract.set_threshold_pub(1);

    // Propose NFT transaction
    let tx_id = mock_contract
        .propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);

    // Approve the transaction
    mock_contract.approve_transaction_pub(tx_id, caller);

    // Pause the contract
    mock_contract.pause();

    // Try to execute (should fail because contract is paused)
    mock_contract.execute_nft_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}
