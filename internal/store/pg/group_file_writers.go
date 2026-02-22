package pg

import (
	"context"

	"github.com/google/uuid"

	"github.com/nextlevelbuilder/goclaw/internal/store"
)

func (s *PGAgentStore) IsGroupFileWriter(ctx context.Context, agentID uuid.UUID, groupID, userID string) (bool, error) {
	var exists bool
	err := s.db.QueryRowContext(ctx,
		`SELECT EXISTS(SELECT 1 FROM group_file_writers WHERE agent_id=$1 AND group_id=$2 AND user_id=$3)`,
		agentID, groupID, userID,
	).Scan(&exists)
	if err != nil {
		return false, err
	}
	return exists, nil
}

func (s *PGAgentStore) AddGroupFileWriter(ctx context.Context, agentID uuid.UUID, groupID, userID, displayName, username string) error {
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO group_file_writers (agent_id, group_id, user_id, display_name, username)
		 VALUES ($1, $2, $3, NULLIF($4,''), NULLIF($5,''))
		 ON CONFLICT (agent_id, group_id, user_id) DO UPDATE SET display_name=NULLIF($4,''), username=NULLIF($5,'')`,
		agentID, groupID, userID, displayName, username,
	)
	return err
}

func (s *PGAgentStore) RemoveGroupFileWriter(ctx context.Context, agentID uuid.UUID, groupID, userID string) error {
	_, err := s.db.ExecContext(ctx,
		`DELETE FROM group_file_writers WHERE agent_id=$1 AND group_id=$2 AND user_id=$3`,
		agentID, groupID, userID,
	)
	return err
}

func (s *PGAgentStore) ListGroupFileWriters(ctx context.Context, agentID uuid.UUID, groupID string) ([]store.GroupFileWriterData, error) {
	rows, err := s.db.QueryContext(ctx,
		`SELECT user_id, display_name, username FROM group_file_writers WHERE agent_id=$1 AND group_id=$2 ORDER BY created_at`,
		agentID, groupID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var writers []store.GroupFileWriterData
	for rows.Next() {
		var w store.GroupFileWriterData
		if err := rows.Scan(&w.UserID, &w.DisplayName, &w.Username); err != nil {
			return nil, err
		}
		writers = append(writers, w)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	return writers, nil
}
