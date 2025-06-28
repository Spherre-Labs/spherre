use core::num::traits::Zero;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events
};
use spherre::components::treasury_handler::TreasuryHandler::{
    Event, TokenTransferred, NftTransferred, TokenLocked, TokenUnlocked
};
use spherre::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use spherre::interfaces::ierc721::{IERC721Dispatcher, IERC721DispatcherTrait};
use spherre::interfaces::itreasury_handler::{
    ITreasuryHandlerDispatcher, ITreasuryHandlerDispatcherTrait
};
use spherre::tests::mocks::mock_nft::{IMockNFTDispatcher, IMockNFTDispatcherTrait};
use spherre::tests::mocks::mock_token::{IMockTokenDispatcher, IMockTokenDispatcherTrait};
use spherre::tests::utils::{TEST_USER};
use starknet::ContractAddress;
use spherre::types::{SmartTokenLock, LockStatus};
use starknet::{contract_address_const, get_block_timestamp};
use snforge_std::{
    start_cheat_block_timestamp, stop_cheat_block_timestamp, start_cheat_caller_address,
    stop_cheat_caller_address, test_address
};
use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

#[starknet::interface]
pub trait IMockTreasuryHandler<TContractState> {
    fn transfer_token(
        ref self: TContractState, token_address: ContractAddress, to: ContractAddress, amount: u256
    );
    fn transfer_nft(
        ref self: TContractState, nft_address: ContractAddress, to: ContractAddress, token_id: u256
    );
    fn lock_tokens(
        ref self: TContractState, token_address: ContractAddress, amount: u256, lock_duration: u64
    ) -> u256;
    fn unlock_tokens(ref self: TContractState, lock_id: u256);
}

#[starknet::contract]
pub mod MockTreasuryHandler {
    use spherre::components::treasury_handler::TreasuryHandler;
    use starknet::ContractAddress;

    component!(path: TreasuryHandler, storage: treasury_handler, event: TreasuryHandlerEvent);

    #[abi(embed_v0)]
    impl TreasuryHandlerImpl = TreasuryHandler::TreasuryHandler<ContractState>;
    impl TreasuryHandlerInternalImpl = TreasuryHandler::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        treasury_handler: TreasuryHandler::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        TreasuryHandlerEvent: TreasuryHandler::Event,
    }

    #[abi(embed_v0)]
    pub impl MockTreasuryHandlerImpl of super::IMockTreasuryHandler<ContractState> {
        fn transfer_token(
            ref self: ContractState,
            token_address: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) {
            self.treasury_handler._transfer_token(token_address, to, amount);
        }

        fn transfer_nft(
            ref self: ContractState,
            nft_address: ContractAddress,
            to: ContractAddress,
            token_id: u256,
        ) {
            self.treasury_handler._transfer_nft(nft_address, to, token_id);
        }

        fn lock_tokens(
            ref self: ContractState,
            token_address: ContractAddress,
            amount: u256,
            lock_duration: u64
        ) -> u256 {
            self.treasury_handler._lock_tokens(token_address, amount, lock_duration)
        }

        fn unlock_tokens(ref self: ContractState, lock_id: u256) {
            self.treasury_handler._unlock_tokens(lock_id)
        }
    }
}

fn deploy_contract(name: ByteArray) -> ContractAddress {
    let class = declare(name).unwrap().contract_class();
    let (addr, _) = class.deploy(@ArrayTrait::new()).unwrap();
    addr
}

#[test]
fn test_get_token_balance() {
    // Deploy MockTreasuryHandler
    let treasury_address = deploy_contract("MockTreasuryHandler");
    let treasury = ITreasuryHandlerDispatcher { contract_address: treasury_address };

    // Deploy MockToken
    let token_address = deploy_contract("MockToken");
    let token = IMockTokenDispatcher { contract_address: token_address };

    // Mint tokens to TreasuryHandler
    let amount: u256 = 1_000_u256;
    token.mint(treasury_address, amount);

    // Verify balance value
    let balance = treasury.get_token_balance(token_address);
    assert(balance == amount, 'Balance should match amount');
}

#[test]
#[should_panic(expected: 'Token address is zero')]
fn test_get_token_balance_zero_address() {
    // Deploy MockTreasuryHandler
    let treasury_address = deploy_contract("MockTreasuryHandler");
    let treasury = ITreasuryHandlerDispatcher { contract_address: treasury_address };

    // Expect panic on zero token address
    treasury.get_token_balance(Zero::zero());
}

#[test]
fn test_is_nft_owner_true() {
    // Deploy MockTreasuryHandler
    let treasury_address = deploy_contract("MockTreasuryHandler");
    let treasury = ITreasuryHandlerDispatcher { contract_address: treasury_address };

    // Deploy MockNFT
    let nft_address = deploy_contract("MockNFT");
    let nft = IMockNFTDispatcher { contract_address: nft_address };

    // Mint NFT to TreasuryHandler
    let token_id: u256 = 7_u256;
    nft.mint(treasury_address, token_id);

    // Verify ownership
    let is_owner = treasury.is_nft_owner(nft_address, token_id);
    assert(is_owner, 'Account should be NFT owner');
}

#[test]
fn test_is_nft_owner_false() {
    // Deploy MockTreasuryHandler
    let treasury_address = deploy_contract("MockTreasuryHandler");
    let treasury = ITreasuryHandlerDispatcher { contract_address: treasury_address };

    // Deploy MockNFT
    let nft_address = deploy_contract("MockNFT");
    let nft = IMockNFTDispatcher { contract_address: nft_address };

    // Mint NFT to another address
    let token_id: u256 = 7_u256;
    nft.mint(TEST_USER(), token_id);

    // Verify non‑ownership
    let is_owner = treasury.is_nft_owner(nft_address, token_id);
    assert(!is_owner, 'Account should not own NFT');
}

#[test]
fn test_transfer_token_success() {
    // Deploy MockTreasuryHandler
    let treasury_address = deploy_contract("MockTreasuryHandler");
    let treasury = IMockTreasuryHandlerDispatcher { contract_address: treasury_address };

    let user = TEST_USER();

    // Deploy MockToken
    let token_address = deploy_contract("MockToken");
    let token = IMockTokenDispatcher { contract_address: token_address };

    // Mint tokens to TreasuryHandler
    let initial_amount: u256 = 500_u256;
    let transfer_amount: u256 = 200_u256;
    token.mint(treasury_address, initial_amount);

    // Execute transfer and spy events
    let mut spy = spy_events();
    treasury.transfer_token(token_address, user, transfer_amount);

    // Verify sender and recipient balances
    let sender_balance = IERC20Dispatcher { contract_address: token_address }
        .balance_of(treasury_address);
    assert(sender_balance == (initial_amount - transfer_amount), 'Sender balance incorrect');

    let recipient_balance = IERC20Dispatcher { contract_address: token_address }.balance_of(user);
    assert(recipient_balance == transfer_amount, 'Recipient balance incorrect');

    // Verify TokenTransferred event emitted
    let expected_event = Event::TokenTransferred(
        TokenTransferred { token: token_address, to: user, amount: transfer_amount, }
    );
    spy.assert_emitted(@array![(treasury_address, expected_event)]);
}

#[test]
#[should_panic(expected: 'Token address is zero')]
fn test_transfer_token_zero_address() {
    // Deploy MockTreasuryHandler
    let treasury_address = deploy_contract("MockTreasuryHandler");
    let treasury = IMockTreasuryHandlerDispatcher { contract_address: treasury_address };

    // Expect panic on zero token address
    treasury.transfer_token(Zero::zero(), TEST_USER(), 1_u256);
}

#[test]
#[should_panic(expected: 'Insufficient token amount')]
fn test_transfer_token_zero_amount() {
    // Deploy MockTreasuryHandler
    let treasury_address = deploy_contract("MockTreasuryHandler");
    let treasury = IMockTreasuryHandlerDispatcher { contract_address: treasury_address };

    // Expect panic on zero transfer amount
    treasury.transfer_token(deploy_contract("MockToken"), TEST_USER(), 0_u256);
}

#[test]
fn test_transfer_nft_success() {
    // Deploy MockTreasuryHandler
    let treasury_address = deploy_contract("MockTreasuryHandler");
    let treasury = IMockTreasuryHandlerDispatcher { contract_address: treasury_address };

    let user = TEST_USER();

    // Deploy MockNFT
    let nft_address = deploy_contract("MockNFT");
    let nft = IMockNFTDispatcher { contract_address: nft_address };

    // Mint NFT to TreasuryHandler
    let token_id: u256 = 10_u256;
    nft.mint(treasury_address, token_id);

    // Execute transfer and spy events
    let mut spy = spy_events();
    treasury.transfer_nft(nft_address, user, token_id);

    // Verify new NFT owner
    let new_owner = IERC721Dispatcher { contract_address: nft_address }.owner_of(token_id);
    assert(new_owner == user, 'NFT should transfer ownership');

    // Verify NftTransferred event emitted
    let expected_event = Event::NftTransferred(
        NftTransferred { nft: nft_address, to: user, token_id: token_id, }
    );
    spy.assert_emitted(@array![(treasury_address, expected_event)]);
}

#[test]
#[should_panic(expected: 'NFT contract address is zero')]
fn test_transfer_nft_zero_address() {
    // Deploy MockTreasuryHandler
    let treasury_address = deploy_contract("MockTreasuryHandler");
    let treasury = IMockTreasuryHandlerDispatcher { contract_address: treasury_address };

    // Expect panic on zero NFT address
    treasury.transfer_nft(Zero::zero(), TEST_USER(), 1_u256);
}

#[test]
#[should_panic(expected: 'Recipient address is zero')]
fn test_transfer_nft_zero_recipient() {
    // Deploy MockTreasuryHandler
    let treasury_address = deploy_contract("MockTreasuryHandler");
    let treasury = IMockTreasuryHandlerDispatcher { contract_address: treasury_address };

    // Deploy MockNFT
    let nft_address = deploy_contract("MockNFT");
    let nft = IMockNFTDispatcher { contract_address: nft_address };

    // Mint NFT to TreasuryHandler
    let token_id: u256 = 1_u256;
    nft.mint(treasury_address, token_id);

    // Expect panic on zero recipient address
    treasury.transfer_nft(nft_address, Zero::zero(), token_id);
}

#[test]
#[should_panic(expected: 'Caller does not own the NFT')]
fn test_transfer_nft_not_owner() {
    // Deploy MockTreasuryHandler
    let treasury_address = deploy_contract("MockTreasuryHandler");
    let treasury = IMockTreasuryHandlerDispatcher { contract_address: treasury_address };

    let user = TEST_USER();

    // Deploy MockNFT
    let nft_address = deploy_contract("MockNFT");
    let nft = IMockNFTDispatcher { contract_address: nft_address };

    // Mint NFT to test user
    let token_id: u256 = 10_u256;
    nft.mint(user, token_id);

    // Expect panic on non‑owner transfer
    treasury.transfer_nft(nft_address, user, token_id);
}

#[test]
fn test_lock_tokens_success() {
    // Deploy MockTreasuryHandler
    let treasury_address = deploy_contract("MockTreasuryHandler");
    let treasury = IMockTreasuryHandlerDispatcher { contract_address: treasury_address };
    let treasury_reader = ITreasuryHandlerDispatcher { contract_address: treasury_address };

    // Deploy MockToken
    let token_address = deploy_contract("MockToken");
    let token = IMockTokenDispatcher { contract_address: token_address };

    // Mint tokens to TreasuryHandler
    let initial_balance: u256 = 1000;
    token.mint(treasury_address, initial_balance);

    // Set up event spy
    let mut spy = spy_events();

    // Lock tokens
    let lock_amount: u256 = 500;
    let lock_duration: u64 = 30; 
    let lock_id = treasury.lock_tokens(token_address, lock_amount, lock_duration);

    // Verify lock was created
    assert(lock_id == 1, 'Lock ID should be 1');

    // Verify available balance decreased
    let available_balance = treasury_reader.get_token_balance(token_address);
    assert(available_balance == initial_balance - lock_amount, 'Available balance incorrect');

    // Verify lock plan details
    let lock_plan = treasury_reader.get_locked_plan_by_id(lock_id);
    assert(lock_plan.token == token_address, 'Token address incorrect');
    assert(lock_plan.token_amount == lock_amount, 'Lock amount incorrect');
    assert(lock_plan.lock_duration == lock_duration, 'Lock duration incorrect');
    assert(lock_plan.lock_status == LockStatus::LOCKED, 'Lock status should be LOCKED');

    // Verify event was emitted
    let expected_event = Event::TokenLocked(
        TokenLocked { 
            lock_id: 1, 
            token: token_address, 
            amount: lock_amount, 
            lock_duration 
        }
    );
    spy.assert_emitted(@array![(treasury_address, expected_event)]);
}

#[test]
fn test_lock_multiple_tokens() {
    // Deploy MockTreasuryHandler
    let treasury_address = deploy_contract("MockTreasuryHandler");
    let treasury = IMockTreasuryHandlerDispatcher { contract_address: treasury_address };
    let treasury_reader = ITreasuryHandlerDispatcher { contract_address: treasury_address };

    // Deploy MockToken
    let token_address = deploy_contract("MockToken");
    let token = IMockTokenDispatcher { contract_address: token_address };

    // Mint tokens to TreasuryHandler
    let initial_balance: u256 = 1000;
    token.mint(treasury_address, initial_balance);

    // First lock
    let lock_amount_1: u256 = 300;
    let lock_id_1 = treasury.lock_tokens(token_address, lock_amount_1, 30);

    // Second lock
    let lock_amount_2: u256 = 200;
    let lock_id_2 = treasury.lock_tokens(token_address, lock_amount_2, 60);

    // Verify both locks exist
    assert(lock_id_1 == 1, 'First lock ID should be 1');
    assert(lock_id_2 == 2, 'Second lock ID should be 2');

    // Verify available balance
    let available_balance = treasury_reader.get_token_balance(token_address);
    assert(available_balance == initial_balance - (lock_amount_1 + lock_amount_2), 'Available balance incorrect');
}

#[test]
#[should_panic(expected: ('Insufficient token amount',))]
fn test_lock_tokens_insufficient_balance() {
    // Deploy MockTreasuryHandler
    let treasury_address = deploy_contract("MockTreasuryHandler");
    let treasury = IMockTreasuryHandlerDispatcher { contract_address: treasury_address };

    // Deploy MockToken
    let token_address = deploy_contract("MockToken");
    let token = IMockTokenDispatcher { contract_address: token_address };

    // Mint insufficient balance
    token.mint(treasury_address, 100);

    // Try to lock more than available
    treasury.lock_tokens(token_address, 200, 30);
}

#[test]
#[should_panic(expected: ('Token address is zero',))]
fn test_lock_tokens_zero_address() {
    // Deploy MockTreasuryHandler
    let treasury_address = deploy_contract("MockTreasuryHandler");
    let treasury = IMockTreasuryHandlerDispatcher { contract_address: treasury_address };

    let zero_address = contract_address_const::<0>();

    // Try to lock with zero address
    treasury.lock_tokens(zero_address, 100, 30);
}

#[test]
#[should_panic(expected: ('Insufficient token amount',))]
fn test_lock_tokens_zero_amount() {
    // Deploy MockTreasuryHandler
    let treasury_address = deploy_contract("MockTreasuryHandler");
    let treasury = IMockTreasuryHandlerDispatcher { contract_address: treasury_address };

    // Deploy MockToken
    let token_address = deploy_contract("MockToken");
    let token = IMockTokenDispatcher { contract_address: token_address };

    token.mint(treasury_address, 1000);

    // Try to lock zero amount
    treasury.lock_tokens(token_address, 0, 30);
}

#[test]
#[should_panic(expected: ('Insufficient token amount',))]
fn test_lock_tokens_zero_duration() {
    // Deploy MockTreasuryHandler
    let treasury_address = deploy_contract("MockTreasuryHandler");
    let treasury = IMockTreasuryHandlerDispatcher { contract_address: treasury_address };

    // Deploy MockToken
    let token_address = deploy_contract("MockToken");
    let token = IMockTokenDispatcher { contract_address: token_address };

    token.mint(treasury_address, 1000);

    // Try to lock with zero duration
    treasury.lock_tokens(token_address, 100, 0);
}

#[test]
fn test_get_all_locked_plans() {
    // Deploy MockTreasuryHandler
    let treasury_address = deploy_contract("MockTreasuryHandler");
    let treasury = IMockTreasuryHandlerDispatcher { contract_address: treasury_address };
    let treasury_reader = ITreasuryHandlerDispatcher { contract_address: treasury_address };

    // Deploy MockToken
    let token_address = deploy_contract("MockToken");
    let token = IMockTokenDispatcher { contract_address: token_address };

    token.mint(treasury_address, 1000);

    // Create multiple locks
    treasury.lock_tokens(token_address, 100, 30);
    treasury.lock_tokens(token_address, 200, 60);
    treasury.lock_tokens(token_address, 300, 90);

    // Get all locked plans
    let locked_plans = treasury_reader.get_all_locked_plans();

    // Verify correct number of plans
    assert(locked_plans.len() == 3, 'Should have 3 locked plans');

    // Verify plan details
    let plan1 = *locked_plans.at(0);
    let plan2 = *locked_plans.at(1);
    let plan3 = *locked_plans.at(2);

    assert(plan1.token_amount == 100, 'Plan 1 amount incorrect');
    assert(plan2.token_amount == 200, 'Plan 2 amount incorrect');
    assert(plan3.token_amount == 300, 'Plan 3 amount incorrect');

    assert(plan1.lock_duration == 30, 'Plan 1 duration incorrect');
    assert(plan2.lock_duration == 60, 'Plan 2 duration incorrect');
    assert(plan3.lock_duration == 90, 'Plan 3 duration incorrect');
}

#[test]
fn test_get_locked_plan_by_id() {
    // Deploy MockTreasuryHandler
    let treasury_address = deploy_contract("MockTreasuryHandler");
    let treasury = IMockTreasuryHandlerDispatcher { contract_address: treasury_address };
    let treasury_reader = ITreasuryHandlerDispatcher { contract_address: treasury_address };

    // Deploy MockToken
    let token_address = deploy_contract("MockToken");
    let token = IMockTokenDispatcher { contract_address: token_address };

    token.mint(treasury_address, 1000);

    // Create a lock
    let lock_amount: u256 = 500;
    let lock_duration: u64 = 45;
    let lock_id = treasury.lock_tokens(token_address, lock_amount, lock_duration);

    // Get lock plan by ID
    let lock_plan = treasury_reader.get_locked_plan_by_id(lock_id);

    // Verify plan details
    assert(lock_plan.token == token_address, 'Token address incorrect');
    assert(lock_plan.token_amount == lock_amount, 'Amount incorrect');
    assert(lock_plan.lock_duration == lock_duration, 'Duration incorrect');
    assert(lock_plan.lock_status == LockStatus::LOCKED, 'Status should be LOCKED');
}
