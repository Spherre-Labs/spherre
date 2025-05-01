#[starknet::component]
pub mod NFTTransaction {
    use spherre::types::NFTTransactionData;
    use starknet::storage::{Map, Vec};
    #[storage]
    pub struct Storage {
        nft_transaction: Map<u256, NFTTransactionData>,
        nft_transaction_ids: Vec<u256>
    }
}
