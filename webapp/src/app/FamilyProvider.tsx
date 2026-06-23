import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { useMyFamilies, type FamilyWithRole } from '../data/queries'

interface FamilyState {
  families: FamilyWithRole[]
  current?: FamilyWithRole
  currentId?: string
  setCurrentId: (id: string) => void
  loading: boolean
}

const FamilyContext = createContext<FamilyState>({
  families: [],
  setCurrentId: () => {},
  loading: true,
})

const LS_KEY = 'riza.currentFamilyId'

export function FamilyProvider({ children }: { children: ReactNode }) {
  const { data: families = [], isLoading } = useMyFamilies()
  const [currentId, setCurrentIdState] = useState<string | undefined>(
    () => localStorage.getItem(LS_KEY) ?? undefined,
  )

  const setCurrentId = (id: string) => {
    localStorage.setItem(LS_KEY, id)
    setCurrentIdState(id)
  }

  // Default to the first family once loaded if none/invalid selected.
  useEffect(() => {
    if (isLoading || families.length === 0) return
    if (!currentId || !families.some((f) => f.id === currentId)) {
      setCurrentId(families[0].id)
    }
  }, [isLoading, families, currentId])

  const current = useMemo(
    () => families.find((f) => f.id === currentId),
    [families, currentId],
  )

  return (
    <FamilyContext.Provider
      value={{ families, current, currentId: current?.id, setCurrentId, loading: isLoading }}
    >
      {children}
    </FamilyContext.Provider>
  )
}

// eslint-disable-next-line react-refresh/only-export-components
export const useFamily = () => useContext(FamilyContext)
