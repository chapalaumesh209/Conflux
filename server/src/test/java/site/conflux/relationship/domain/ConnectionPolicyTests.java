package site.conflux.relationship.domain;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class ConnectionPolicyTests {

    @Test
    void createsConversationOnlyForAMutualConnection() {
        var outcome = ConnectionPolicy.resolve(MeetDecision.CONNECT, MeetDecision.CONNECT);

        assertThat(outcome.status()).isEqualTo(ConnectionStatus.CONNECTED);
        assertThat(outcome.conversationCreated()).isTrue();
    }

    @Test
    void keepsARejectionPrivateAndDoesNotCreateAConversation() {
        var outcome = ConnectionPolicy.resolve(MeetDecision.CONNECT, MeetDecision.NEXT);

        assertThat(outcome.status()).isEqualTo(ConnectionStatus.DECLINED);
        assertThat(outcome.conversationCreated()).isFalse();
    }
}
