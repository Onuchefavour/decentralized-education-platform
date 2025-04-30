;; core-education-platform
;; 
;; This contract serves as the backbone of the CoreLoop educational platform, 
;; handling core functionality including content registration, verification workflows, 
;; credential issuance, and governance mechanics. It implements a decentralized
;; education ecosystem where content creators, validators, and learners interact
;; without central intermediaries while maintaining quality through community governance.

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-ROLE (err u101))
(define-constant ERR-CONTENT-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-VERIFIED (err u103))
(define-constant ERR-INSUFFICIENT-REPUTATION (err u104))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u105))
(define-constant ERR-ALREADY-VOTED (err u106))
(define-constant ERR-PROPOSAL-CLOSED (err u107))
(define-constant ERR-INVALID-CREDENTIAL (err u108))
(define-constant ERR-CONTENT-NOT-VERIFIED (err u109))
(define-constant ERR-COURSE-NOT-COMPLETED (err u110))
(define-constant ERR-ALREADY-ENROLLED (err u111))
(define-constant ERR-NOT-ENROLLED (err u112))

;; User roles
(define-constant ROLE-ADMIN u1)
(define-constant ROLE-CONTENT-CREATOR u2)
(define-constant ROLE-VALIDATOR u3)
(define-constant ROLE-LEARNER u4)

;; Verification status
(define-constant STATUS-PENDING u1)
(define-constant STATUS-VERIFIED u2)
(define-constant STATUS-REJECTED u3)

;; Proposal status
(define-constant PROPOSAL-ACTIVE u1)
(define-constant PROPOSAL-PASSED u2)
(define-constant PROPOSAL-REJECTED u3)

;; Data maps and variables

;; Track users and their roles
(define-map users 
  { user: principal } 
  { roles: (list 10 uint), reputation: uint }
)

;; Educational content storage
(define-map content-registry 
  { content-id: uint } 
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    content-hash: (buff 32),
    verification-status: uint,
    subject-area: (string-ascii 50),
    creation-time: uint,
    verified-by: (optional principal),
    price: uint
  }
)

;; Track content verification history
(define-map verification-history
  { content-id: uint, validator: principal }
  {
    timestamp: uint,
    decision: uint,
    feedback: (string-ascii 500)
  }
)

;; Track learner course enrollments
(define-map learner-enrollments
  { learner: principal, content-id: uint }
  {
    enrollment-date: uint,
    completion-status: bool,
    completion-date: (optional uint)
  }
)

;; Track credentials issued to learners
(define-map credentials
  { credential-id: uint }
  {
    learner: principal,
    content-id: uint,
    issue-date: uint,
    issuer: principal,
    credential-hash: (buff 32)
  }
)

;; Governance proposals
(define-map governance-proposals
  { proposal-id: uint }
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 1000),
    status: uint,
    creation-time: uint,
    end-time: uint,
    yes-votes: uint,
    no-votes: uint
  }
)

;; Track votes cast on proposals
(define-map proposal-votes
  { proposal-id: uint, voter: principal }
  { vote: bool }
)

;; Track content sequence
(define-data-var content-id-nonce uint u0)

;; Track credential sequence
(define-data-var credential-id-nonce uint u0)

;; Track proposal sequence
(define-data-var proposal-id-nonce uint u0)

;; Contract owner for admin functions
(define-data-var contract-owner principal tx-sender)

;; Private functions

;; Generate a new content ID
(define-private (get-next-content-id)
  (begin
    (var-set content-id-nonce (+ (var-get content-id-nonce) u1))
    (var-get content-id-nonce)
  )
)

;; Generate a new credential ID
(define-private (get-next-credential-id)
  (begin
    (var-set credential-id-nonce (+ (var-get credential-id-nonce) u1))
    (var-get credential-id-nonce)
  )
)

;; Generate a new proposal ID
(define-private (get-next-proposal-id)
  (begin
    (var-set proposal-id-nonce (+ (var-get proposal-id-nonce) u1))
    (var-get proposal-id-nonce)
  )
)

;; Check if user has a specific role
(define-private (has-role (user principal) (role uint))
  (match (map-get? users { user: user })
    user-data (is-some (index-of (get roles user-data) role))
    false
  )
)

;; Admin only function check
(define-private (is-admin (user principal))
  (has-role user ROLE-ADMIN)
)

;; Check if user is content creator
(define-private (is-content-creator (user principal))
  (has-role user ROLE-CONTENT-CREATOR)
)

;; Check if user is validator
(define-private (is-validator (user principal))
  (has-role user ROLE-VALIDATOR)
)

;; Check if user is learner
(define-private (is-learner (user principal))
  (has-role user ROLE-LEARNER)
)

;; Update user reputation
(define-private (update-reputation (user principal) (delta int))
  (match (map-get? users { user: user })
    user-data 
      (let ((new-reputation (+ (get reputation user-data) (if (< delta 0) 
                                                           (if (> (abs delta) (get reputation user-data)) 
                                                               (to-int (* (get reputation user-data) u-1)) 
                                                               delta)
                                                           delta))))
        (map-set users 
          { user: user } 
          { roles: (get roles user-data), reputation: (to-uint new-reputation) }))
    ERR-NOT-AUTHORIZED
  )
)

;; Read-only functions

;; Get user information
(define-read-only (get-user-info (user principal))
  (map-get? users { user: user })
)

;; Get content details
(define-read-only (get-content (content-id uint))
  (map-get? content-registry { content-id: content-id })
)

;; Get verification history for content
(define-read-only (get-verification (content-id uint) (validator principal))
  (map-get? verification-history { content-id: content-id, validator: validator })
)

;; Get learner enrollment status
(define-read-only (get-enrollment-status (learner principal) (content-id uint))
  (map-get? learner-enrollments { learner: learner, content-id: content-id })
)

;; Get credential details
(define-read-only (get-credential (credential-id uint))
  (map-get? credentials { credential-id: credential-id })
)

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
  (map-get? governance-proposals { proposal-id: proposal-id })
)

;; Check if user has voted on proposal
(define-read-only (has-voted (proposal-id uint) (voter principal))
  (is-some (map-get? proposal-votes { proposal-id: proposal-id, voter: voter }))
)

;; Public functions

;; Initialize contract owner and admin
(define-public (initialize-admin (admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (map-set users 
      { user: admin } 
      { roles: (list ROLE-ADMIN), reputation: u100 })
    (ok true)
  )
)

;; Register a new user with roles
(define-public (register-user (user principal) (roles (list 10 uint)))
  (begin
    (asserts! (or (is-admin tx-sender) (is-eq tx-sender (var-get contract-owner))) ERR-NOT-AUTHORIZED)
    (map-set users 
      { user: user } 
      { roles: roles, reputation: u10 })
    (ok true)
  )
)

;; Self-registration as a learner
(define-public (register-as-learner)
  (let ((user tx-sender))
    (match (map-get? users { user: user })
      user-data 
        (map-set users 
          { user: user } 
          { roles: (unwrap! (as-max-len? (append (get roles user-data) ROLE-LEARNER) u10) ERR-INVALID-ROLE), 
            reputation: (get reputation user-data) })
      ;; If user doesn't exist, create new user with learner role
      (map-set users 
        { user: user } 
        { roles: (list ROLE-LEARNER), reputation: u5 })
    )
    (ok true)
  )
)

;; Register new educational content
(define-public (register-content 
                (title (string-ascii 100)) 
                (description (string-ascii 500)) 
                (content-hash (buff 32))
                (subject-area (string-ascii 50))
                (price uint))
  (let ((content-id (get-next-content-id))
        (creator tx-sender))
    
    ;; Check that sender is a content creator
    (asserts! (is-content-creator creator) ERR-NOT-AUTHORIZED)
    
    ;; Store the content in the registry
    (map-set content-registry
      { content-id: content-id }
      {
        creator: creator,
        title: title,
        description: description,
        content-hash: content-hash,
        verification-status: STATUS-PENDING,
        subject-area: subject-area,
        creation-time: block-height,
        verified-by: none,
        price: price
      }
    )
    
    (ok content-id)
  )
)

;; Submit verification for content
(define-public (verify-content 
                (content-id uint) 
                (decision uint) 
                (feedback (string-ascii 500)))
  (let ((validator tx-sender))
    
    ;; Verify validator role and minimum reputation
    (asserts! (is-validator validator) ERR-NOT-AUTHORIZED)
    (asserts! (>= (default-to u0 (get reputation (map-get? users { user: validator }))) u20) ERR-INSUFFICIENT-REPUTATION)
    
    ;; Get the content to verify
    (match (map-get? content-registry { content-id: content-id })
      content-data
        (begin
          ;; Check content isn't already verified
          (asserts! (is-eq (get verification-status content-data) STATUS-PENDING) ERR-ALREADY-VERIFIED)
          
          ;; Record verification decision
          (map-set verification-history
            { content-id: content-id, validator: validator }
            {
              timestamp: block-height,
              decision: decision,
              feedback: feedback
            }
          )
          
          ;; Update content verification status
          (map-set content-registry
            { content-id: content-id }
            (merge content-data { 
              verification-status: decision, 
              verified-by: (some validator)
            })
          )
          
          ;; Update reputation for both validator and content creator
          (if (is-eq decision STATUS-VERIFIED)
            (begin
              (update-reputation validator 5)
              (update-reputation (get creator content-data) 10)
            )
            (update-reputation (get creator content-data) -5)
          )
          
          (ok true)
        )
      ERR-CONTENT-NOT-FOUND
    )
  )
)

;; Enroll in a course
(define-public (enroll-in-course (content-id uint))
  (let ((learner tx-sender))
    
    ;; Verify learner role
    (asserts! (is-learner learner) ERR-NOT-AUTHORIZED)
    
    ;; Check that content exists and is verified
    (match (map-get? content-registry { content-id: content-id })
      content-data
        (begin
          ;; Check that content is verified
          (asserts! (is-eq (get verification-status content-data) STATUS-VERIFIED) ERR-CONTENT-NOT-VERIFIED)
          
          ;; Check that learner is not already enrolled
          (asserts! (is-none (map-get? learner-enrollments { learner: learner, content-id: content-id })) ERR-ALREADY-ENROLLED)
          
          ;; Record enrollment
          (map-set learner-enrollments
            { learner: learner, content-id: content-id }
            {
              enrollment-date: block-height,
              completion-status: false,
              completion-date: none
            }
          )
          
          (ok true)
        )
      ERR-CONTENT-NOT-FOUND
    )
  )
)

;; Mark course as completed
(define-public (complete-course (content-id uint))
  (let ((learner tx-sender))
    
    ;; Check that learner is enrolled
    (match (map-get? learner-enrollments { learner: learner, content-id: content-id })
      enrollment-data
        (begin
          ;; Update enrollment to completed
          (map-set learner-enrollments
            { learner: learner, content-id: content-id }
            {
              enrollment-date: (get enrollment-date enrollment-data),
              completion-status: true,
              completion-date: (some block-height)
            }
          )
          
          ;; Update learner reputation
          (update-reputation learner 2)
          
          (ok true)
        )
      ERR-NOT-ENROLLED
    )
  )
)

;; Issue credential for completed course
(define-public (issue-credential 
                (learner principal) 
                (content-id uint) 
                (credential-hash (buff 32)))
  (let ((issuer tx-sender))
    
    ;; Check that issuer is a validator or admin
    (asserts! (or (is-validator issuer) (is-admin issuer)) ERR-NOT-AUTHORIZED)
    
    ;; Check that learner has completed the course
    (match (map-get? learner-enrollments { learner: learner, content-id: content-id })
      enrollment-data
        (begin
          (asserts! (get completion-status enrollment-data) ERR-COURSE-NOT-COMPLETED)
          
          ;; Generate credential
          (let ((credential-id (get-next-credential-id)))
            (map-set credentials
              { credential-id: credential-id }
              {
                learner: learner,
                content-id: content-id,
                issue-date: block-height,
                issuer: issuer,
                credential-hash: credential-hash
              }
            )
            
            ;; Update reputation
            (update-reputation learner 10)
            (update-reputation issuer 2)
            
            (ok credential-id)
          )
        )
      ERR-NOT-ENROLLED
    )
  )
)

;; Create governance proposal
(define-public (create-proposal 
                (title (string-ascii 100)) 
                (description (string-ascii 1000)) 
                (voting-period uint))
  (let ((proposer tx-sender)
        (proposal-id (get-next-proposal-id)))
    
    ;; Check that proposer has sufficient reputation
    (match (map-get? users { user: proposer })
      user-data
        (begin
          (asserts! (>= (get reputation user-data) u50) ERR-INSUFFICIENT-REPUTATION)
          
          ;; Store the proposal
          (map-set governance-proposals
            { proposal-id: proposal-id }
            {
              proposer: proposer,
              title: title,
              description: description,
              status: PROPOSAL-ACTIVE,
              creation-time: block-height,
              end-time: (+ block-height voting-period),
              yes-votes: u0,
              no-votes: u0
            }
          )
          
          (ok proposal-id)
        )
      ERR-NOT-AUTHORIZED
    )
  )
)

;; Vote on a proposal
(define-public (vote-on-proposal (proposal-id uint) (vote bool))
  (let ((voter tx-sender))
    
    ;; Get proposal
    (match (map-get? governance-proposals { proposal-id: proposal-id })
      proposal-data
        (begin
          ;; Check proposal is still active
          (asserts! (is-eq (get status proposal-data) PROPOSAL-ACTIVE) ERR-PROPOSAL-CLOSED)
          (asserts! (<= block-height (get end-time proposal-data)) ERR-PROPOSAL-CLOSED)
          
          ;; Check voter hasn't already voted
          (asserts! (is-none (map-get? proposal-votes { proposal-id: proposal-id, voter: voter })) ERR-ALREADY-VOTED)
          
          ;; Get voter's reputation for vote weight
          (match (map-get? users { user: voter })
            user-data
              (let ((reputation (get reputation user-data))
                    (yes-votes (get yes-votes proposal-data))
                    (no-votes (get no-votes proposal-data)))
                
                ;; Record the vote
                (map-set proposal-votes
                  { proposal-id: proposal-id, voter: voter }
                  { vote: vote }
                )
                
                ;; Update vote counts
                (map-set governance-proposals
                  { proposal-id: proposal-id }
                  (merge proposal-data {
                    yes-votes: (if vote (+ yes-votes reputation) yes-votes),
                    no-votes: (if vote no-votes (+ no-votes reputation))
                  })
                )
                
                (ok true)
              )
            ERR-NOT-AUTHORIZED
          )
        )
      ERR-PROPOSAL-NOT-FOUND
    )
  )
)

;; Finalize proposal after voting period
(define-public (finalize-proposal (proposal-id uint))
  (begin
    ;; Get proposal
    (match (map-get? governance-proposals { proposal-id: proposal-id })
      proposal-data
        (begin
          ;; Check proposal is active and voting period has ended
          (asserts! (is-eq (get status proposal-data) PROPOSAL-ACTIVE) ERR-PROPOSAL-CLOSED)
          (asserts! (>= block-height (get end-time proposal-data)) ERR-PROPOSAL-NOT-FOUND)
          
          ;; Determine result
          (let ((yes-votes (get yes-votes proposal-data))
                (no-votes (get no-votes proposal-data))
                (result (if (> yes-votes no-votes) PROPOSAL-PASSED PROPOSAL-REJECTED)))
            
            ;; Update proposal status
            (map-set governance-proposals
              { proposal-id: proposal-id }
              (merge proposal-data { status: result })
            )
            
            ;; Update proposer reputation based on outcome
            (update-reputation 
              (get proposer proposal-data) 
              (if (is-eq result PROPOSAL-PASSED) 25 -10))
            
            (ok result)
          )
        )
      ERR-PROPOSAL-NOT-FOUND
    )
  )
)

;; Update content metadata (only for creator)
(define-public (update-content 
                (content-id uint) 
                (title (string-ascii 100)) 
                (description (string-ascii 500))
                (subject-area (string-ascii 50))
                (price uint))
  (let ((updater tx-sender))
    
    ;; Get content
    (match (map-get? content-registry { content-id: content-id })
      content-data
        (begin
          ;; Check permission
          (asserts! (or 
                      (is-eq updater (get creator content-data)) 
                      (is-admin updater)
                    ) ERR-NOT-AUTHORIZED)
          
          ;; Update content
          (map-set content-registry
            { content-id: content-id }
            (merge content-data {
              title: title,
              description: description,
              subject-area: subject-area,
              price: price
            })
          )
          
          (ok true)
        )
      ERR-CONTENT-NOT-FOUND
    )
  )
)