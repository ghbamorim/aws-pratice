"""create items table

Revision ID: 0001
Revises:
"""
import sqlalchemy as sa

from alembic import op

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "items",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("attachment_key", sa.String(length=512), nullable=True),
    )


def downgrade():
    op.drop_table("items")
