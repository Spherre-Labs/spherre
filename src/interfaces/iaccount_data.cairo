#[starknet::interface]
pub trait IThresholdHandler<TContractState> {
    fn get_threshold(self: @TContractState) -> (u64, u64);
}

