// apps/web/app/layout.tsx
export const metadata = { title: 'Soneh Dashboard' };
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <body style={{ fontFamily: 'ui-sans-serif, system-ui', maxWidth: 960, margin: '0 auto', padding: 16 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, margin: '16px 0' }}>Soneh — Dashboard</h1>
        {children}
      </body>
    </html>
  );
}
