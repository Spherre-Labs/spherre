#[starknet::interface]
pub trait IThresholdHandler<TContractState> {
    //This takes no arguments and returns a tuple in which the first member is a threshold and the
    //second is members_count of an account
    fn get(self: @TContractState) -> (u64, u64);
}

