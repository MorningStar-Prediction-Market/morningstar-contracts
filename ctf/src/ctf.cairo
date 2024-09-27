use core::starknet::ContractAddress;

#[starknet::interface]
trait IConditionalTokens<T> {
    /// @dev Function that returns the current vote status
    fn prepare_condition(
        self: @T, oracle: ContractAddress, question_id: felt252, outcome_slot_count: u256,
    );

    // fn report_payouts(self: @T, question_id: felt252, payouts: Array<u256>,);

    // fn split_position(
    //     self: @T,
    //     collateral_token: ContractAddress,
    //     parent_collection_id: felt252,
    //     condition_id: felt252,
    //     partition: Array<u256>,
    //     amount: u256,
    // );

    // fn merge_positions(
    //     self: @T,
    //     collateral_token: ContractAddress,
    //     parent_collection_id: felt252,
    //     condition_id: felt252,
    //     partition: Array<u256>,
    //     amount: u256,
    // );

    // fn redeem_positions(
    //     self: @T,
    //     collateral_token: ContractAddress,
    //     parent_collection_id: felt252,
    //     condition_id: felt252,
    //     index_sets: Array<u256>,
    // );

    // helper functions
    fn get_condition_id(
        self: @T, oracle: ContractAddress, question_id: felt252, outcome_slot_count: u128,
    ) -> felt252;

    fn get_collection_id(
        self: @T, parent_collection_id: felt252, condition_id: felt252, index_set: u128,
    ) -> felt252;

    fn get_position_id(
        self: @T, collateral_token: ContractAddress, collection_id: felt252,
    ) -> felt252;
}

#[starknet::contract]
mod ctf {
    use core::starknet::ContractAddress;
    use core::starknet::storage::{Map};
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::{ERC1155Component, ERC1155HooksEmptyImpl};
    use core::poseidon::{PoseidonTrait,};
    use core::hash::{HashStateTrait,};

    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC1155 Mixin
    #[abi(embed_v0)]
    impl ERC1155MixinImpl = ERC1155Component::ERC1155MixinImpl<ContractState>;
    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ConditionPreparation: ConditionPreparation,
        ConditionResolution: ConditionResolution,
        PositionSplit: PositionSplit,
        PositionsMerge: PositionsMerge,
        PayoutRedemption: PayoutRedemption,
        #[flat]
        ERC1155Event: ERC1155Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[derive(Drop, starknet::Event)]
    struct ConditionPreparation {
        #[key]
        condition_id: felt252,
        oracle: ContractAddress,
        question_id: felt252,
        outcome_slot_count: u256,
    }
    #[derive(Drop, starknet::Event)]
    struct ConditionResolution {
        #[key]
        condition_id: felt252,
        #[key]
        oracle: ContractAddress,
        #[key]
        question_id: felt252,
        outcome_slot_count: u256,
        payout_numerators: Array<u256>,
    }

    #[derive(Drop, starknet::Event)]
    struct PositionSplit {
        #[key]
        stakeholder: ContractAddress,
        collateral_token: felt252,
        #[key]
        parent_collection_id: felt252,
        #[key]
        condition_id: felt252,
        partition: Array<u256>,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct PositionsMerge {
        #[key]
        stakeholder: ContractAddress,
        collateral_token: felt252,
        #[key]
        parent_collection_id: felt252,
        #[key]
        condition_id: felt252,
        partition: Array<u256>,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct PayoutRedemption {
        #[key]
        redeemer: ContractAddress,
        #[key]
        collateral_token: felt252,
        #[key]
        parent_collection_id: felt252,
        #[key]
        condition_id: felt252,
        index_sets: Array<u256>,
        payout: u256,
    }

    // Define the ConditionalTokensStorage struct
    #[storage]
    struct Storage {
        // Storage variables
        payout_numerators: Map<(felt252, u256), u256>,
        payout_denominator: Map<felt252, u256>,
        outcome_slot_counts: Map<felt252, u256>,
        balances: Map<(ContractAddress, felt252), u256>,
        total_supplies: Map<felt252, u256>,
        #[substorage(v0)]
        erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }
    #[constructor]
    fn constructor(
        ref self: ContractState,
        token_uri: ByteArray,
        recipient: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>
    ) {
        self.erc1155.initializer(token_uri);
        self
            .erc1155
            .batch_mint_with_acceptance_check(recipient, token_ids, values, array![].span());
    }
    #[abi(embed_v0)]
    impl ConditionalTokensImpl of super::IConditionalTokens<ContractState> {
        fn get_condition_id(
            self: @ContractState,
            oracle: ContractAddress,
            question_id: felt252,
            outcome_slot_count: u128,
        ) -> felt252 {
            let oracle_felt: felt252 = oracle.into();
            // Convert outcome_slot_count to felt252 (assuming it fits within felt252)
            let outcome_slot_count_felt: felt252 = outcome_slot_count.into();

            // Initialize Poseidon hash state
            let hash_state = PoseidonTrait::new();

            // Update the hash state with each element
            let hash_state = hash_state
                .update(oracle_felt)
                .update(question_id)
                .update(outcome_slot_count_felt);

            // Finalize the hash computation
            let condition_id = hash_state.finalize();
            condition_id
        }

        // Helper function to compute collection ID
        fn get_collection_id(
            self: @ContractState,
            parent_collection_id: felt252,
            condition_id: felt252,
            index_set: u128,
        ) -> felt252 {
            let index_set_felt: felt252 = index_set.into();
            // Initialize Poseidon hash state
            let hash_state = PoseidonTrait::new();

            // Update the hash state with each element
            let hash_state = hash_state
                .update(parent_collection_id)
                .update(condition_id)
                .update(index_set_felt);

            // Finalize the hash computation
            let collection_id = hash_state.finalize();
            collection_id
        }

        // Helper function to compute position ID
        fn get_position_id(
            self: @ContractState, collateral_token: ContractAddress, collection_id: felt252,
        ) -> felt252 {
            let collateral_felt: felt252 = collateral_token.into();
            // Initialize Poseidon hash state
            let hash_state = PoseidonTrait::new();

            // Update the hash state with each element
            let hash_state = hash_state.update(collateral_felt).update(collection_id);

            // Finalize the hash computation
            let position_id = hash_state.finalize();
            position_id
        }
        fn prepare_condition(
            self: @ContractState,
            oracle: ContractAddress,
            question_id: felt252,
            outcome_slot_count: u256,
        ) {
            // Ensure outcome_slot_count is valid
            let max_outcomes: u256 = 256_u128.into();
            assert!(outcome_slot_count <= max_outcomes, "too many outcome slots");

            let min_outcomes: u256 = 1_u128.into();
            assert!(
                outcome_slot_count > min_outcomes, "there should be more than one outcome slot"
            );
        }

        // fn report_payouts(self: @ContractState, question_id: felt252, payouts: Array<u256>,) {
        //     // Get outcome_slot_count from payouts length
        //     let outcome_slot_count: u128 = payouts.len().into();

        //     // Ensure outcome_slot_count is valid
        //     let min_outcomes: u128 = 1_u128.into();
        //     assert!(
        //         outcome_slot_count > min_outcomes, "There should be more than one outcome slot"
        //     );

        //     // Get oracle (caller address)
        //     let oracle: ContractAddress = get_caller_address();

        //     assert!(!oracle.is_zero(), "invalid oralce address {:?}", oracle);
        //     // Compute condition_id
        //     let condition_id = self.get_condition_id(oracle, question_id, outcome_slot_count);
        //     // // Check if condition is prepared
        // // let stored_outcome_slot_count = self.outcome_slot_counts.read(condition_id);
        // // assert!(stored_outcome_slot_count != u256_zero(), "Condition not prepared or found");
        // // assert!(
        // //     stored_outcome_slot_count == outcome_slot_count, "Incorrect outcome_slot_count"
        // // );

        //     // // Check that the condition is not already resolved
        // // let existing_denominator = self.payout_denominator.read(condition_id);
        // // assert!(existing_denominator == u256_zero(), "Payout denominator already set");

        //     // // Initialize denominator
        // // let mut den: u256 = u256_zero();

        //     // // Iterate over payouts and store them
        // // for (i, payout) in payouts
        // //     .iter()
        // //     .enumerate() {
        // //         den = den + *payout;

        //     //         // Store the payout numerator
        // //         let index = u256_from_usize(i);
        // //         self.payout_numerators.write((condition_id, index), *payout);
        // //     }

        //     // // Check that den > 0
        // // assert!(den > u256_zero(), "Payout is all zeroes");

        //     // // Store the denominator
        // // self.payout_denominator.write(condition_id, den);

        //     // // Convert payouts to Array<u256> for the event
        // // let payouts_array = payouts.into_iter().cloned().collect::<Array<u256>>();

        //     // // Emit ConditionResolution event
        // // let event = Event::ConditionResolution(
        // //     ConditionResolution {
        // //         condition_id: condition_id,
        // //         oracle: oracle,
        // //         question_id: question_id,
        // //         outcome_slot_count: outcome_slot_count,
        // //         payout_numerators: payouts_array,
        // //     }
        // // );
        // // event.emit();
        // }
    }
}
