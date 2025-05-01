#[starknet::component]
pub mod ChangeThresholdTransaction {
    use spherre::types::ThresholdChangeData;
    use starknet::storage::{Map, Vec};
    #[storage]
    pub struct Storage {
        threshold_change_transactions: Map<u256, ThresholdChangeData>,
        threshold_change_transactions_ids: Vec<u256>
    }
}
