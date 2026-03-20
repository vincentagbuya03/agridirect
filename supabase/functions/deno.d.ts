// Minimal type stubs for Deno globals and npm: specifiers.
// These allow VS Code to type-check edge function files without the Deno extension.
// When the Deno extension IS installed, it supersedes these declarations.

declare namespace Deno {
  interface Env {
    get(key: string): string | undefined;
  }
  const env: Env;

  function serve(
    handler: (req: Request) => Response | Promise<Response>,
    options?: { port?: number },
  ): void;
}

declare module 'npm:nodemailer@6.9.9' {
  interface TransportOptions {
    host?: string;
    port?: number;
    secure?: boolean;
    auth?: { user: string; pass: string };
  }
  interface MailOptions {
    from?: string;
    to?: string | string[];
    subject?: string;
    text?: string;
    html?: string;
  }
  interface Transporter {
    sendMail(options: MailOptions): Promise<unknown>;
  }
  function createTransport(options: TransportOptions): Transporter;
  const _default: { createTransport: typeof createTransport };
  export default _default;
}
