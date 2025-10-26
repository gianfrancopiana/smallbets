interface SectionHeaderProps {
  title: string
  action?: React.ReactNode
  id?: string
}

export default function SectionHeader({
  title,
  action,
  id,
}: SectionHeaderProps) {
  return (
    <div className="flex flex-col !pl-[var(--shelf-side-pad)] sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h2
          id={id}
          className="text-foreground pl-1 text-xl leading-tight font-medium tracking-wider capitalize select-none"
        >
          {title}
        </h2>
      </div>

      {action}
    </div>
  )
}
