package config

import (
	"testing"
)

func TestCleanConnectionString(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "empty",
			input:    "",
			expected: "",
		},
		{
			name:     "quoted and trimmed",
			input:    `"postgresql://user:pass@host/db"`,
			expected: "postgresql://user:pass@host/db",
		},
		{
			name:     "single-quoted and trimmed",
			input:    `'postgresql://user:pass@host/db'`,
			expected: "postgresql://user:pass@host/db",
		},
		{
			name: "multiline neon url with newlines and spaces",
			input: "postgresql://neondb_owner:secret@ep-gentle-truth-\n  b1uvzned-pooler.c-5.eu-central-1.aws.neon.\n  tech/neondb?sslmode=require&channel_binding=require",
			expected: "postgresql://neondb_owner:secret@ep-gentle-truth-b1uvzned-pooler.c-5.eu-central-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := cleanConnectionString(tt.input)
			if got != tt.expected {
				t.Errorf("cleanConnectionString(%q) = %q, want %q", tt.input, got, tt.expected)
			}
		})
	}
}
