use core::num::traits::Zero;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events
};
use spherre::components::treasury_handler::TreasuryHandler::{
    Event, TokenTransferred, NftTransferred
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

#[starknet::interface]
pub trait IMockTreasuryHandler<TContractState> {
    fn transfer_token(
        ref self: TContractState, token_address: ContractAddress, to: ContractAddress, amount: u256
    );
    fn transfer_nft(
        ref self: TContractState, nft_address: ContractAddress, to: ContractAddress, token_id: u256
    );
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
