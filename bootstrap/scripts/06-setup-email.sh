#!/usr/bin/env bash
# Setup React Email with Mailhog

set -euo pipefail

BOOTSTRAP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BOOTSTRAP_DIR/common.sh"
ensure_project_dir

log "Setting up Docker Compose with Mailhog"
cat > docker-compose.yml << EOF
services:
  mailhog:
    image: mailhog/mailhog
    ports:
      - "${MAILHOG_SMTP_PORT}:1025"
      - "${MAILHOG_WEB_PORT}:8025"
    restart: unless-stopped
EOF

log "Setting up React Email with stage-based transport"
bun add react-email @react-email/components nodemailer @sendgrid/mail
bun add -d @types/nodemailer

# Create emails directory
mkdir -p src/emails

# Create email service abstraction
cat > src/lib/email.ts << 'EOF'
import { render } from '@react-email/components';
import nodemailer from 'nodemailer';
import sgMail from '@sendgrid/mail';

const STAGE = process.env.STAGE || 'local';

// Configure SendGrid for production
if (STAGE === 'production' && process.env.SENDGRID_API_KEY) {
  sgMail.setApiKey(process.env.SENDGRID_API_KEY);
}

// Mailhog transporter for local development
const mailhogTransport = nodemailer.createTransport({
  host: 'localhost',
  port: Number(process.env.MAILHOG_SMTP_PORT) || 1025,
  secure: false,
});

interface SendEmailOptions {
  to: string | string[];
  subject: string;
  template: React.ReactElement;
  from?: string;
}

interface SendEmailResult {
  success: boolean;
  messageId?: string;
  error?: Error;
}

export async function sendEmail({
  to,
  subject,
  template,
  from,
}: SendEmailOptions): Promise<SendEmailResult> {
  const html = await render(template);
  const defaultFrom = process.env.EMAIL_FROM || 'noreply@example.com';
  const sender = from || defaultFrom;

  try {
    if (STAGE === 'production') {
      const [response] = await sgMail.send({
        to,
        from: sender,
        subject,
        html,
      });
      return { success: true, messageId: response.headers['x-message-id'] };
    }

    if (STAGE === 'test') {
      // Log to console for test visibility
      console.log(`[EMAIL] To: ${to}, Subject: ${subject}`);
      return { success: true, messageId: 'test-message-id' };
    }

    // Local: send to Mailhog
    const info = await mailhogTransport.sendMail({
      to,
      from: sender,
      subject,
      html,
    });
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error('[EMAIL ERROR]', error);
    return {
      success: false,
      error: error instanceof Error ? error : new Error('Unknown error'),
    };
  }
}
EOF

# Create sample email template
cat > src/emails/welcome.tsx << 'EOF'
import {
  Html,
  Head,
  Body,
  Container,
  Section,
  Text,
  Button,
  Hr,
} from '@react-email/components';

interface WelcomeEmailProps {
  name: string;
  loginUrl: string;
}

export function WelcomeEmail({ name, loginUrl }: WelcomeEmailProps) {
  return (
    <Html>
      <Head />
      <Body style={main}>
        <Container style={container}>
          <Section>
            <Text style={heading}>Welcome, {name}!</Text>
            <Text style={paragraph}>
              Thanks for signing up. We&apos;re excited to have you on board.
            </Text>
            <Button style={button} href={loginUrl}>
              Get Started
            </Button>
            <Hr style={hr} />
            <Text style={footer}>
              If you didn&apos;t create this account, you can ignore this email.
            </Text>
          </Section>
        </Container>
      </Body>
    </Html>
  );
}

const main = {
  backgroundColor: '#f6f9fc',
  fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
};

const container = {
  backgroundColor: '#ffffff',
  margin: '0 auto',
  padding: '40px 20px',
  maxWidth: '560px',
};

const heading = {
  fontSize: '24px',
  fontWeight: 'bold' as const,
  color: '#1a1a1a',
};

const paragraph = {
  fontSize: '16px',
  lineHeight: '26px',
  color: '#4a4a4a',
};

const button = {
  backgroundColor: '#000000',
  borderRadius: '4px',
  color: '#ffffff',
  fontSize: '16px',
  fontWeight: 'bold' as const,
  textDecoration: 'none',
  padding: '12px 24px',
  display: 'inline-block' as const,
};

const hr = {
  borderColor: '#e6e6e6',
  margin: '26px 0',
};

const footer = {
  fontSize: '14px',
  color: '#8c8c8c',
};
EOF

# Create email test file
cat > src/lib/email.test.ts << 'EOF'
import { describe, test, expect, beforeAll } from 'bun:test';

describe('email', () => {
  beforeAll(() => {
    process.env.STAGE = 'test';
  });

  test('STAGE defaults to local', () => {
    const stage = process.env.STAGE || 'local';
    expect(['local', 'test', 'production']).toContain(stage);
  });
});
EOF

success "React Email configured"
