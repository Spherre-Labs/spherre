//! This module implements the ChangeThresholdTransaction component.
//! It allows for proposing and executing threshold change transactions.
//! It includes methods for proposing, retrieving, and executing threshold change transactions.
//!
//!
//! The comment documentation of the public entrypoints can be found in the interface
//! `IChangeThresholdTransaction`.

#[starknet::component]
pub mod ChangeThresholdTransaction {
    use core::num::traits::Zero;
    use openzeppelin::security::PausableComponent::InternalImpl as PausableInternalImpl;
    use openzeppelin::security::PausableComponent;
    use spherre::account_data::AccountData::{AccountDataImpl, InternalImpl, InternalTrait};
    use spherre::account_data::AccountData;
    use spherre::components::permission_control::PermissionControl;
    use spherre::errors::Errors;
    use spherre::interfaces::iaccount_data::IAccountData;
    use spherre::interfaces::ichange_threshold_tx::IChangeThresholdTransaction;
    use spherre::types::{ThresholdChangeData, Transaction, TransactionType};
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };

    #[storage]
    pub struct Storage {
        threshold_change_transactions: Map<u256, ThresholdChangeData>,
        threshold_change_transaction_ids: Vec<u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ThresholdChangeProposed: ThresholdChangeProposed,
        ThresholdChangeExecuted: ThresholdChangeExecuted,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ThresholdChangeProposed {
        #[key]
        pub id: u256,
        pub new_threshold: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ThresholdChangeExecuted {
        #[key]
        pub id: u256,
        pub new_threshold: u64,
    }

    #[embeddable_as(ChangeThresholdTransaction)]
    pub impl ChangeThresholdTransactionImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl AccData: AccountData::HasComponent<TContractState>,
        impl PermissionCntrl: PermissionControl::HasComponent<TContractState>,
        impl Pausable: PausableComponent::HasComponent<TContractState>,
    > of IChangeThresholdTransaction<ComponentState<TContractState>> {
        fn propose_threshold_change_transaction(
            ref self: ComponentState<TContractState>, new_threshold: u64,
        ) -> u256 {
            // Pause guard
            let pausable = get_dep_component!(@self, Pausable);
            pausable.assert_not_paused();

            // Validate inputs
            assert(new_threshold.is_non_zero(), Errors::NON_ZERO_THRESHOLD);
            let account_data_comp = get_dep_component!(@self, AccData);
            let (current_threshold, _) = account_data_comp.get_threshold();
            assert(new_threshold != current_threshold, Errors::ERR_THRESHOLD_UNCHANGED);
            let total_voters = account_data_comp.get_number_of_voters();
            assert(new_threshold <= total_voters, Errors::ERR_THRESHOLD_EXCEEDS_VOTERS);

            // Create transaction in AccountData
            let mut account_data_comp = get_dep_component_mut!(ref self, AccData);
            let tx_id = account_data_comp.create_transaction(TransactionType::THRESHOLD_CHANGE);

            // Store threshold change data
            let threshold_tx_data = ThresholdChangeData { new_threshold };
            self.threshold_change_transactions.entry(tx_id).write(threshold_tx_data);
            self.threshold_change_transaction_ids.append().write(tx_id);

            // Emit event
            self.emit(ThresholdChangeProposed { id: tx_id, new_threshold });

            tx_id
        }

        fn get_threshold_change_transaction(
            self: @ComponentState<TContractState>, id: u256,
        ) -> ThresholdChangeData {
            let account_data_comp = get_dep_component!(self, AccData);
            let transaction: Transaction = account_data_comp.get_transaction(id);
            assert(
                transaction.tx_type == TransactionType::THRESHOLD_CHANGE,
                Errors::ERR_INVALID_THRESHOLD_TRANSACTION,
            );
            self.threshold_change_transactions.entry(id).read()
        }

        fn get_all_threshold_change_transactions(
            self: @ComponentState<TContractState>,
        ) -> Array<ThresholdChangeData> {
            let mut array: Array<ThresholdChangeData> = array![];
            let range_stop = self.threshold_change_transaction_ids.len();
            for index in 0
                ..range_stop {
                    let id = self.threshold_change_transaction_ids.at(index).read();
                    let tx = self.threshold_change_transactions.entry(id).read();
                    array.append(tx);
                };
            array
        }
        fn execute_threshold_change_transaction(
            ref self: ComponentState<TContractState>, id: u256,
        ) {
            // Pause guard
            let pausable = get_dep_component!(@self, Pausable);
            pausable.assert_not_paused();

            let mut account_data_comp = get_dep_component_mut!(ref self, AccData);

            // Validate transaction data
            let threshold_change_data = self.get_threshold_change_transaction(id);

            let (current_threshold, _) = account_data_comp.get_threshold();
            assert(
                threshold_change_data.new_threshold != current_threshold,
                Errors::ERR_THRESHOLD_UNCHANGED,
            );
            let total_voters = account_data_comp.get_number_of_voters();
            assert(
                threshold_change_data.new_threshold <= total_voters,
                Errors::ERR_THRESHOLD_EXCEEDS_VOTERS,
            );

            // Execute the transaction (All validation will be done)
            account_data_comp.execute_transaction(id);

            // Update threshold in AccountData
            account_data_comp.set_threshold(threshold_change_data.new_threshold);

            // Emit event
            self
                .emit(
                    ThresholdChangeExecuted {
                        id, new_threshold: threshold_change_data.new_threshold,
                    },
                );
        }
    }
}
