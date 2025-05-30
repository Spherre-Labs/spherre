use spherre::types::ThresholdChangeData;

#[starknet::interface]
pub trait IChangeThresholdTransaction<TContractState> {
    fn propose_threshold_change_transaction(ref self: TContractState, new_threshold: u64) -> u256;
    fn get_threshold_change_transaction(self: @TContractState, id: u256) -> ThresholdChangeData;
    fn get_all_threshold_change_transactions(self: @TContractState) -> Array<ThresholdChangeData>;
}
