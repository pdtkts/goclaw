CREATE TABLE group_file_writers (
    agent_id     UUID NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    group_id     VARCHAR(255) NOT NULL,
    user_id      VARCHAR(255) NOT NULL,
    display_name VARCHAR(255),
    username     VARCHAR(255),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (agent_id, group_id, user_id)
);
