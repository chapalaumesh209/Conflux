package site.conflux.identity.persistence;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.repository.Repository;

interface UserAccountRepository extends Repository<UserAccount, UUID> {
    Optional<UserAccount> findByEmail(String email);
    UserAccount save(UserAccount account);
}
