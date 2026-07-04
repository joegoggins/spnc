import type { ReactNode } from 'react'

// Deliberately tiny Markdown -> React renderer for the UX sketch. Builds React
// nodes directly (never dangerouslySetInnerHTML), so user-authored text can't
// inject HTML. Supports headings, bold/italic, links, bullet lists, and
// paragraphs — enough to demo the "write about" step. Swap for react-markdown
// if we outgrow it.

function renderInline(text: string, keyPrefix: string): ReactNode[] {
  // Split on **bold**, *italic*, and [label](url); everything else is literal.
  const pattern = /(\*\*[^*]+\*\*|\*[^*]+\*|\[[^\]]+\]\([^)]+\))/g
  const parts = text.split(pattern).filter((p) => p !== '')
  return parts.map((part, i) => {
    const key = `${keyPrefix}-${i}`
    if (part.startsWith('**') && part.endsWith('**')) {
      return <strong key={key}>{part.slice(2, -2)}</strong>
    }
    if (part.startsWith('*') && part.endsWith('*')) {
      return <em key={key}>{part.slice(1, -1)}</em>
    }
    const link = part.match(/^\[([^\]]+)\]\(([^)]+)\)$/)
    if (link) {
      const href = link[2]
      const safe = /^(https?:|mailto:)/i.test(href) ? href : '#'
      return (
        <a key={key} href={safe} target="_blank" rel="noreferrer noopener">
          {link[1]}
        </a>
      )
    }
    return <span key={key}>{part}</span>
  })
}

export function Markdown({ source }: { source: string }) {
  const blocks = source.replace(/\r\n/g, '\n').split(/\n{2,}/)
  const out: ReactNode[] = []

  blocks.forEach((block, bi) => {
    const trimmed = block.trim()
    if (!trimmed) return

    const heading = trimmed.match(/^(#{1,3})\s+(.*)$/)
    if (heading) {
      const level = heading[1].length
      const content = renderInline(heading[2], `h-${bi}`)
      if (level === 1) out.push(<h2 key={`b-${bi}`}>{content}</h2>)
      else if (level === 2) out.push(<h3 key={`b-${bi}`}>{content}</h3>)
      else out.push(<h4 key={`b-${bi}`}>{content}</h4>)
      return
    }

    const lines = trimmed.split('\n')
    if (lines.every((l) => /^[-*]\s+/.test(l))) {
      out.push(
        <ul key={`b-${bi}`}>
          {lines.map((l, li) => (
            <li key={li}>{renderInline(l.replace(/^[-*]\s+/, ''), `li-${bi}-${li}`)}</li>
          ))}
        </ul>,
      )
      return
    }

    // paragraph; single newlines become <br/>
    out.push(
      <p key={`b-${bi}`}>
        {lines.flatMap((l, li) => {
          const nodes = renderInline(l, `p-${bi}-${li}`)
          return li === 0 ? nodes : [<br key={`br-${li}`} />, ...nodes]
        })}
      </p>,
    )
  })

  return <div className="md">{out}</div>
}
