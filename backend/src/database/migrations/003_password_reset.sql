-- Migration 003 : password reset
-- Never modify this file once it is applied somewhere : add a new migration instead.

-- "Forgot password" link : SHA-256 of the token of the link (the token itself is only in the email),
-- removed once the password is changed so that the link works only once
ALTER TABLE user
    ADD COLUMN password_reset_token      CHAR(64) NULL UNIQUE AFTER email_change_expires_at,
    ADD COLUMN password_reset_expires_at DATETIME NULL         AFTER password_reset_token;
