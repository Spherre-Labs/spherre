use spherre::types::SmartTokenLockTransaction;
use starknet::ContractAddress;

#[starknet::interface]
pub trait ISmartTokenLockTransaction<TContractState> {
    fn propose_smart_token_lock_transaction(
        ref self: TContractState, token: ContractAddress, amount: u256, duration: u64
    ) -> u256;
    fn get_smart_token_lock_transaction(
        self: @TContractState, transaction_id: u256
    ) -> SmartTokenLockTransaction;
    fn smart_token_lock_transaction_list(self: @TContractState) -> Array<SmartTokenLockTransaction>;
}
