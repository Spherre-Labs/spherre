#[starknet::component]
pub mod AccountData {
    use spherre::types::{TransactionStatus, TransactionType};
    use starknet::storage::{Map};
<<<<<<< HEAD
    use starknet::{ContractAddress};
=======
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};


>>>>>>> 0a79ae7 (Added public function, private function, event, and tests)
    #[storage]
    pub struct Storage {
        transactions: Map<u256, Transaction>,
        tx_count: u256, // the transaction length
        threshold: u64, // the number of members required to approve a transaction for it to be executed
        members: Map<u64, ContractAddress>, // Map(id, member) the members of the account
        pub members_count: u64 // the member length, (had to make this public for testing purposes.)
    }

    #[starknet::storage_node]
    pub struct Transaction {
        id: u256,
        tx_type: TransactionType,
        tx_status: TransactionStatus,
        date_created: u64,
        date_executed: u64,
<<<<<<< HEAD
=======
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ThresholdUpdated: ThresholdUpdated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ThresholdUpdated {
        threshold: u64,
        date_updated: u64,
    }

    use crate::interfaces::iaccount_data::IThresholdHandler;
    #[embeddable_as(ThresholdHandler)]
    impl ThresholdHandlerImpl<
        TContractState, +HasComponent<TContractState>,
    > of IThresholdHandler<ComponentState<TContractState>> {
        fn get(self: @ComponentState<TContractState>) -> (u64, u64) {
            let threshold: u64 = self.threshold.read();
            let members_count: u64 = self.members_count.read();
            (threshold, members_count)
        }
    }


    #[generate_trait]
    pub impl ThresholdSetterImpl<
        TContractState, +HasComponent<TContractState>,
    > of ThresholdSetterTrait<TContractState> {
        //This is a private function that sets a threshold agter asserting threshold < members_count

        fn set_threshold(ref self: ComponentState<TContractState>, threshold: u64) {
            // This function sets threshold if
            use spherre::errors::ThresholdError;
            let members_count: u64 = self.members_count.read();
            assert(threshold < members_count, ThresholdError);
            self.threshold.write(threshold);
        }

        fn add_threshold_info(
            ref self: ComponentState<TContractState>, threshold: u64, date_updated: u64,
        ) {
            // This function emits the threshold and date_updated;
            self.emit(ThresholdUpdated { threshold, date_updated });
        }
>>>>>>> 0a79ae7 (Added public function, private function, event, and tests)
    }
}

