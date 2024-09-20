use core::starknet::ContractAddress;

#[starknet::interface]
trait IConditionalTokens<T> {
    /// @dev Function that returns the current vote status
    fn prepare_condition(
        self: @T, oracle: ContractAddress, question_id: felt252, outcome_slot_count: u256,
    );
}
#[starknet::contract]
mod ctf {
    use core::starknet::ContractAddress;
    use core::starknet::storage::{Map};
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::{ERC1155Component, ERC1155HooksEmptyImpl};

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
    }
}
